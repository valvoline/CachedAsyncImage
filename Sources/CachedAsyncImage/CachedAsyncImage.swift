import SwiftUI

/// A lightweight, cache-aware async image loader for SwiftUI.
///
/// `CachedAsyncImage` fetches an image using a `URLRequest`, builds an `Image` on success,
/// and renders phases (`empty`, `success`, `failure`) through a caller-provided `content`
/// builder—mirroring the ergonomics of `AsyncImage` while giving you control over caching
/// via the request's `cachePolicy`.
///
/// The view animates a cross-fade between the previous and the new phase using the provided
/// `transaction`. The network task is started on `onAppear` and cancelled on `onDisappear`.
///
/// - Important: This view runs on the `MainActor`.
/// - Note: The actual caching behavior is governed by `URLSession` and the `URLRequest`
///   `cachePolicy`. No custom cache layer is added here.
/// - SeeAlso: `AsyncImage`, `URLRequest.CachePolicy`.
///
///
@MainActor
public struct CachedAsyncImage<Content: View>: View {
    // MARK: Environment
    
    /// The current display scale (e.g., 2.0 or 3.0) taken from the environment.
    /// Used as a default `UIImage` scale when `scale` is `nil`.
    @Environment(\.displayScale) private var displayScale
    
    // MARK: Configuration
    
    /// The request used to load image data. Its `cachePolicy` dictates how cached
    /// responses are used. If `nil`, no request is performed and the phase stays `.empty`.
    private var urlRequest: URLRequest?
    
    /// Optional explicit scale to apply when constructing the `UIImage`.
    /// If `nil`, falls back to `displayScale`.
    private var scale: CGFloat?
    
    /// The transaction used for implicit animations (e.g., the cross-fade
    /// between old and new phases).
    private var transaction: Transaction = .init(animation: .easeInOut)
    
    /// Alignment of the layered phases in the `ZStack`.
    private var alignment: Alignment = .leading
    
    /// Builder that renders the current `AsyncImagePhase` into content.
    @ViewBuilder private var content: (AsyncImagePhase) -> Content
    
    // MARK: State
    
    /// The current loading/rendering phase.
    @State private var phase: AsyncImagePhase = .empty
    
    /// The previously rendered phase, used to animate a fade transition
    /// when a new phase becomes available.
    @State private var oldPhase: AsyncImagePhase = .empty
    
    /// Controls which phase is drawn on top during the cross-fade.
    @State private var showNewOnTop = false
    
    /// The in-flight loading task, cancelled on `onDisappear`.
    @State private var loadingTask: Task<Void, Never>?
    
    // MARK: Initializers
    
    /// Creates a `CachedAsyncImage` with a `URL` and request options.
    ///
    /// - Parameters:
    ///   - url: The image URL.
    ///   - cachePolicy: The `URLRequest.CachePolicy` to use. Defaults to `.returnCacheDataElseLoad`.
    ///   - timeoutInterval: The request timeout in seconds. Defaults to 60.
    ///   - scale: Optional explicit image scale. Defaults to `nil` (uses environment scale).
    ///   - transaction: The `Transaction` for animations. Defaults to `.easeInOut`.
    ///   - alignment: Alignment of layered content in the `ZStack`. Defaults to `.leading`.
    ///   - content: A builder that maps an `AsyncImagePhase` to a view.
    ///
    /// - Example:
    /// ```swift
    /// CachedAsyncImage(url: URL(string: "https://example.com/avatar.png")!) { phase in
    ///     switch phase {
    ///     case .empty:
    ///         ProgressView()
    ///     case .success(let image):
    ///         image
    ///             .resizable()
    ///             .scaledToFill()
    ///     case .failure:
    ///         Image(systemName: "photo")
    ///     @unknown default:
    ///         EmptyView()
    ///     }
    /// }
    /// .frame(width: 80, height: 80)
    /// .clipShape(Circle())
    /// ```
    ///
    /// - Note: Pass a different `cachePolicy` (e.g. `.reloadIgnoringLocalCacheData`)
    ///   when you need to bypass cached responses.
    public init(
        url: URL,
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad,
        timeoutInterval: TimeInterval = 60.0,
        scale: CGFloat? = nil,
        transaction: Transaction = .init(animation: .easeInOut),
        alignment: Alignment = .leading,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.urlRequest = URLRequest(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
        self.scale = scale
        self.transaction = transaction
        self.alignment = alignment
        self.content = content
        
        // Explicit State initialization for clarity in library contexts.
        self._phase = State(initialValue: .empty)
        self._oldPhase = State(initialValue: .empty)
        self._showNewOnTop = State(initialValue: false)
        self._loadingTask = State(initialValue: nil)
    }
    
    /// Creates a `CachedAsyncImage` from an optional `URLRequest`.
    ///
    /// Use this initializer when you already have a fully configured request
    /// (custom headers, specific cache policy, etc.). If `urlRequest` is `nil`,
    /// no request is performed and the phase remains `.empty`.
    ///
    /// - Parameters:
    ///   - urlRequest: The (optional) `URLRequest` to execute.
    ///   - scale: Optional explicit image scale. Defaults to `nil` (uses environment scale).
    ///   - transaction: The `Transaction` for animations. Defaults to `.easeInOut`.
    ///   - alignment: Alignment of layered content in the `ZStack`. Defaults to `.leading`.
    ///   - content: A builder that maps an `AsyncImagePhase` to a view.
    public init(
        urlRequest: URLRequest?,
        scale: CGFloat? = nil,
        transaction: Transaction = .init(animation: .easeInOut),
        alignment: Alignment = .leading,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.urlRequest = urlRequest
        self.scale = scale
        self.transaction = transaction
        self.alignment = alignment
        self.content = content
        
        self._phase = State(initialValue: .empty)
        self._oldPhase = State(initialValue: .empty)
        self._showNewOnTop = State(initialValue: false)
        self._loadingTask = State(initialValue: nil)
    }
    
    // MARK: Body
    
    /// Renders the previous and current phases in a layered stack and applies
    /// the configured transaction to cross-fade between them.
    public var body: some View {
        ZStack(alignment: alignment) {
            content(oldPhase)
                .opacity(showNewOnTop ? 0 : 1)
                .zIndex(showNewOnTop ? 0 : 1)
            
            content(phase)
                .opacity(showNewOnTop ? 1 : 0)
                .zIndex(showNewOnTop ? 1 : 0)
        }
        .transaction { $0 = transaction }
        .onAppear {
            loadingTask = Task {
                if let urlRequest {
                    do {
                        // Perform the request using URLSession. Cache behavior is driven by `urlRequest.cachePolicy`.
                        let response = try await URLSession.shared.data(for: urlRequest)
                        if let uiImage = UIImage(data: response.0, scale: scale ?? displayScale) {
                            oldPhase = phase
                            phase = AsyncImagePhase.success(Image(uiImage: uiImage))
                            showNewOnTop = true
                        }
                    } catch {
                        oldPhase = phase
                        phase  = AsyncImagePhase.failure(error)
                        showNewOnTop = true
                    }
                }
            }
        }
        .onDisappear {
            // Cancel in-flight work when the view goes off-screen.
            loadingTask?.cancel()
            loadingTask = nil
        }
    }
}

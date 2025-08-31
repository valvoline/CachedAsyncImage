# 📸 CachedAsyncImage

A lightweight, cache-aware async image loader for SwiftUI.  
It works similarly to `AsyncImage`, but gives you full control over `URLRequest` (including `cachePolicy`, timeout, and custom headers).

- ✅ Drop-in replacement for `AsyncImage`
- ✅ Supports custom `URLRequest` (headers, cache policy, etc.)
- ✅ Smooth cross-fade transition between phases
- ✅ Automatic task cancellation on `onDisappear`
- ✅ Zero external dependencies

[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square)](https://swift.org)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat-square)](https://swift.org/package-manager/)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg?style=flat-square)](https://opensource.org/licenses/BSD-3-Clause)


---

## 🚀 Installation

### Swift Package Manager (SPM)

Add this package in **Xcode**:

```
File > Add Packages > https://github.com/valvoline/CachedAsyncImage.git
```

Or add it directly in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/valvoline/CachedAsyncImage.git", from: "1.0.0")
]
```

---

## 📖 Usage

### Basic Example

```swift
import SwiftUI
import CachedAsyncImage

struct AvatarView: View {
    let url = URL(string: "https://example.com/avatar.png")!

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(.secondary)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .shadow(radius: 4)
    }
}
```

---

## ⚙️ Initialization Options

### With URL

```swift
CachedAsyncImage(
    url: URL(string: "https://example.com/image.png")!,
    cachePolicy: .returnCacheDataElseLoad,
    timeoutInterval: 30.0,
    scale: nil,
    transaction: Transaction(animation: .easeInOut),
    alignment: .center
) { phase in
    // content builder
}
```

### With URLRequest

```swift
let request = URLRequest(
    url: URL(string: "https://example.com/image.png")!,
    cachePolicy: .reloadIgnoringLocalCacheData
)

CachedAsyncImage(urlRequest: request) { phase in
    switch phase {
    case .success(let image):
        image.resizable()
    default:
        Color.gray // fallback
    }
}
```

---

## 🛠️ Design Notes & Trade-offs

- **Why not `AsyncImage`?**  
  SwiftUI’s built-in `AsyncImage` doesn’t allow configuring `URLRequest`. This package provides the same ergonomics while exposing full request control.

- **Caching**  
  Caching is **fully delegated to `URLSession`** and the `URLRequest.cachePolicy`.  
  No custom cache layer is added, keeping it lightweight and predictable.

- **Cross-fade Transition**  
  The view overlays old and new phases in a `ZStack` and animates opacity via `Transaction`, ensuring smooth transitions.

- **Lifecycle Management**  
  Any in-flight request is cancelled automatically in `onDisappear`.

- **Error Handling**  
  Failures surface as `.failure(error)`. You decide how to render them (placeholder, retry button, etc.).

---

## 🎨 Advanced Customization

### Custom Placeholder

```swift
CachedAsyncImage(url: url) { phase in
    switch phase {
    case .empty:
        ZStack {
            Color.gray.opacity(0.3)
            ProgressView("Loading…")
        }
    case .success(let image):
        image
            .resizable()
            .scaledToFit()
    case .failure:
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
    @unknown default:
        EmptyView()
    }
}
.frame(width: 200, height: 120)
.cornerRadius(12)
```

---

### Retry Button on Failure

```swift
struct RetryableImage: View {
    let url: URL

    @State private var reloadToken = UUID()

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable()
            case .failure:
                VStack {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(.red)
                    Button("Retry") {
                        reloadToken = UUID() // triggers reinit
                    }
                }
            default:
                ProgressView()
            }
        }
        .id(reloadToken) // forces CachedAsyncImage to reload
    }
}
```

---

### Custom Animations

```swift
CachedAsyncImage(
    url: url,
    transaction: Transaction(animation: .spring())
) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .transition(.scale.combined(with: .opacity))
    default:
        ProgressView()
    }
}
```

---

## 🤝 Contributing

Contributions are welcome!  
Feel free to open issues or submit pull requests if you find bugs or want new features.

---

## 📄 License

This project is licensed under the **BSD License**.  
See [LICENSE](LICENSE) for details.

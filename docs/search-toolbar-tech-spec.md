# Search Toolbar Technical Spec

## Search Tab Entry Point
The `Tab(role: .search)` declaration in `ContentView` tells UIKit that this tab should host an immersive search experience. When combined with `.searchable`, iOS materializes the floating search toolbar shown in the design.

```swift
// ContentView.swift
Tab(role: .search) {
    SearchTab()
        .environment(\.imageNS, imageNS)
        .environment(\.videoNS, videoNS)
}
```

`SearchTab` itself only wraps a `NavigationStack` so the navigation chrome (including the search toolbar) remains system managed:

```swift
// SearchTab.swift
NavigationStack(path: $path) {
    SearchView()
        .navigationDestinations(path: $path)
}
```

## Search Field Wiring
`SearchView` owns the SwiftUI state driving the toolbar’s text field, search scope, loading spinner, and results. The `.searchable` modifier binds the bottom toolbar’s field to `@State private var searchText` using the principal toolbar placement, which instructs UIKit to anchor the field along the bottom for a search-role tab.

```swift
// SearchView.swift
.searchable(
    text: $searchText,
    placement: .toolbarPrincipal,
    prompt: "Search \(searchScope.rawValue)"
)
.searchScopes($searchScope) {
    ForEach(SearchScope.allCases) { scope in
        Text(scope.rawValue).tag(scope)
    }
}
.onSubmit(of: .search) {
    Task { await performSearch() }
}
```

`performSearch()` fans out to the appropriate Reddit API endpoint and repaints the list with async results:

```swift
// SearchView.swift
private func performSearch() async {
    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        subredditResults = []
        postResults = []
        return
    }
    isLoading = true
    defer { isLoading = false }

    switch searchScope {
    case .subreddits:
        subredditResults = await RedditAPI.searchSubreddits(searchText, limit: 25) ?? []
    case .posts:
        postResults = await RedditAPI.searchPosts(searchText, limit: 25) ?? []
    }
}
```

`RedditAPI.searchSubreddits` wraps the `/subreddits/search` endpoint and transforms the listing response into lightweight `Subreddit` models:

```swift
// RedditAPI+Search.swift
static func searchSubreddits(_ query: String, limit: Int = 30) async -> [Subreddit]? {
    let queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "sort", value: "relevance"),
        URLQueryItem(name: "raw_json", value: "1")
    ]
    let listing: SubredditListing? = await performSearch(
        query: query,
        endpoint: "subreddits/search",
        queryItems: queryItems,
        responseType: SubredditListing.self
    )
    return listing?.data.children.compactMap { child in
        guard child.kind == "t5" else { return nil }
        return Subreddit(data: child.data)
    }
}
```

## Clear Button Placement
The “Clear” button in the screenshot is a `ToolbarItem` in the primary action slot. Because the tab bar occupies the usual bottom toolbar area, the system hoists this action to the top-right of the navigation bar while leaving the bottom search bar unobstructed.

```swift
// SearchView.swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button(role: .destructive) {
            searchText = ""
            subredditResults = []
            postResults = []
        } label: {
            Text("Clear")
        }
        .disabled(searchText.isEmpty && searchResults.isEmpty)
    }
}
```

## Result Selection
Rows are interactive buttons that push deeper navigation using the injected `appendToPath` environment value. Selecting a subreddit transitions the stack to a `PostsList` configured for that community.

```swift
// SubredditRowView.swift
Button {
    appendToPath(PostFeedType.subreddit(subreddit))
} label: {
    Label {
        Text(subreddit.displayNamePrefixed)
        if subreddit.subscriberCount > 0 {
            Text("\(subreddit.formattedSubscriberCount) subscribers")
        }
    } icon: { /* avatar rendering omitted */ }
    Spacer()
    Image(systemName: "chevron.right")
}
.buttonStyle(.plain)
```

## System Toolbar Behavior Summary
Because the tab uses the search role and the view exposes `.searchable` with the principal placement, UIKit delivers the glassmorphic, bottom-aligned toolbar automatically. The field gains focus on tab reselection, collapses when scrolling, and hands off animations to the keyboard without any custom code. Avoid adding custom `.toolbar` items with `.bottomBar` placement to keep the system presenter intact. Future enhancements (debounced search, focus management, etc.) should be layered on top of the existing SwiftUI bindings so the toolbar continues to flow from the platform defaults.

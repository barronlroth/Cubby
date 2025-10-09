# Implementing Liquid Glass and New SwiftUI Design Patterns in iOS 26

## Overview of Liquid Glass and SwiftUI Updates in iOS 26

Liquid Glass is Apple’s new design language introduced in iOS 26\. It treats toolbars, tab bars and other control layers as a fluid digital material that reflects and refracts content underneath while maintaining clear separation from the main content. Apple’s **WWDC 2025** sessions explain that Liquid Glass bends and shapes light, adapts to device size and provides dynamic lensing effects[\[1\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=sophisticated%20system%2C%20working%20together,which%20is%20permanently%20transparent%20and). Developers do not manually implement this effect for container views; navigation, tab, toolbar and sheet components automatically adopt glass when built with **Xcode 26**[\[2\]](https://developer.apple.com/videos/play/wwdc2025/256/#:~:text=Search%20is%20now%20bottom%20aligned,it%20more%20ergonomic%20to%20reach). Two variants exist – *regular* and *clear* – and the regular glass should be used for typical toolbars and tabs; the clear variant is recommended only when content behind is bright and simple, such as over media[\[1\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=sophisticated%20system%2C%20working%20together,which%20is%20permanently%20transparent%20and). Apple emphasises that glass should only be applied to the **navigation layer**; content views like lists or forms should not have a glass background[\[3\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=17%3A03).

Besides the visual overhaul, SwiftUI gained new APIs. The framework version most associated with iOS 26 is **SwiftUI 6**, packaged alongside the Swift 6.2 language update[\[4\]](https://www.infoworld.com/article/4005538/apple-rolls-out-swift-swiftui-and-xcode-updates.html#:~:text=1,7). These updates bring macros for animations and binding, improved performance, bridging with UIKit/AppKit, 3D charts and enhanced drag‑and‑drop[\[5\]](https://useyourloaf.com/blog/wwdc-2025-viewing-guide/#:~:text=There%E2%80%99s%20work%20to%20be%20done,apps%20for%20the%20new%20design). The following sections explain how to adopt Liquid Glass in various UI components, focusing on search patterns, tabs, toolbars, forms and custom views.

## Search Patterns and Implementation

### Search in Toolbars (Navigation Containers)

In iOS 26 the searchable modifier applied to a NavigationStack or NavigationSplitView automatically inserts a glassy search field into the system toolbar. On **iPhone**, the search field floats at the bottom of the screen; on **iPad/Mac** it appears in the top‑trailing corner[\[2\]](https://developer.apple.com/videos/play/wwdc2025/256/#:~:text=Search%20is%20now%20bottom%20aligned,it%20more%20ergonomic%20to%20reach). Developers no longer need to embed search fields manually in the view hierarchy – simply call .searchable(text:) on the navigation container. The system manages the glass effect and placement.

When search is not central to the experience, the field may be minimized to a search icon. Use the modifier searchToolbarBehavior(.minimize) to allow this behavior[\[6\]](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/#:~:text=the%20new%20SwiftUI%20modifier%20searchToolbarBehavior,the%20number%20of%20toolbar%20items). On scroll, the toolbar can also shrink via searchToolbarBehavior(.collapse) to reveal more content. Key points:

* **Automatic placement:** .searchable on navigation containers places the search bar at the bottom (iPhone) or top‑trailing (iPad/Mac)[\[2\]](https://developer.apple.com/videos/play/wwdc2025/256/#:~:text=Search%20is%20now%20bottom%20aligned,it%20more%20ergonomic%20to%20reach).

* **Minimization:** .searchToolbarBehavior(.minimize) compresses the search field into a button when inactive[\[6\]](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/#:~:text=the%20new%20SwiftUI%20modifier%20searchToolbarBehavior,the%20number%20of%20toolbar%20items).

* **Multiple search scopes:** searchable still accepts suggestions and scoping options; they appear below the glass bar.

* **Old design comparison:** In iOS 15–17, developers often embedded SearchBar in List headers or placed ToolbarItem(placement:.navigationBar) search fields. In iOS 26 this is discouraged—placing search within content disrupts the glass design.

### Dedicated Search Page (Tab‑bar Search Role)

For apps with multiple tabs, Apple encourages moving global search into its own tab. SwiftUI’s new Tab API accepts a .search role. When a tab has .search role, the system detaches it from other tabs and transforms the entire tab bar into a full‑width search field when selected[\[7\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=var%20body%3A%20some%20View%20,%2F%2F%20content). This search page presents suggestions or a List of results; pressing other tabs collapses the search field back into a button.

Implementation steps:

1. Define a TabView containing Tab instances.

2. For the search tab, supply the .search role:

* Tab(role: .search) {  
      SearchView() // content for dedicated search page  
  } label: {  
      Label("Search", systemImage: "magnifyingglass")  
  }

* This tab morphs into a search field when active[\[7\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=var%20body%3A%20some%20View%20,%2F%2F%20content).

3. For other tabs, use .home, .favorites or no role. The new API allows tabBarMinimizeBehavior(.onScrollDown) to collapse the tab bar when scrolling[\[8\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=.tabViewStyle%28.sidebarAdaptable%29%20.tabViewBottomAccessory%20%7B%20Button%28,).

### Advanced Search Toolbar Features

* **Toolbar spacing and grouping:** Use ToolbarSpacer to separate multiple toolbar items into groups. It can have fixed or flexible spacing values[\[9\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=ToolbarItemPlacement%20become%20really%20important%20while,applies%20the%20glassProminent%20button%20style).

* **Persistent search on larger devices:** On iPad and Mac, .searchable places the search field in the top trailing of the navigation bar and persists even when nested in sidebars[\[10\]](https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/#:~:text=With%20the%20introduction%20of%20the,an%C2%A0expanded%C2%A0and%C2%A0compact%C2%A0state%20to%20prioritize%20screen%20content).

* **Sidebar placement:** If search should appear in the sidebar of a NavigationSplitView, specify placement: .sidebar in searchable[\[11\]](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/#:~:text=content%20types%20introduced%20in%20iOS,kind%2C%20and%20ToolbarSpacer).

## Tab Bars and Minimized Behavior

### Automatic Glass Tab Bars

Recompiling a SwiftUI TabView with Xcode 26 automatically adopts a translucent, blurred tab bar. The bar floats above the content and shrinks when the user scrolls down using tabBarMinimizeBehavior(.onScrollDown)[\[8\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=.tabViewStyle%28.sidebarAdaptable%29%20.tabViewBottomAccessory%20%7B%20Button%28,). On iPad or macOS, the tab bar appears more compact; on iPhone the system expands it for comfortable thumb reach.

### Bottom Accessory and Floating Buttons

The new tabViewBottomAccessory modifier allows developers to attach a custom view above the tab bar. This is useful for persistent filters, progress bars or call‑to‑action banners[\[8\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=.tabViewStyle%28.sidebarAdaptable%29%20.tabViewBottomAccessory%20%7B%20Button%28,). Avoid misusing the search role for generic actions; Apple’s guidelines caution that the search tab should only initiate search[\[12\]](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/#:~:text=In%20the%20health%20app%20example,role). For floating action buttons, wrap the button with glassEffect(.regular.interactive()) to create a floating glass shape and position it using ZStack[\[13\]](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/#:~:text=ZStack%28alignment%3A%20.bottomTrailing%29%20,contents).

## Toolbars and Navigation Bars

### New Toolbar Layout

Toolbars in iOS 26 automatically adopt Liquid Glass. Apple recommends pairing icons with textual labels for actions to improve clarity[\[14\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=As%20you%20can%20see%20in,both%20images%20and%20text%20labels). To group items, use ToolbarSpacer with fixed or flexible spacing; this ensures items remain separated into groups and the glass effect morphs seamlessly[\[9\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=ToolbarItemPlacement%20become%20really%20important%20while,applies%20the%20glassProminent%20button%20style). Primary actions should be tinted or badged using .tint and .badge to stand out, but avoid over‑tinting since glass surfaces already have dynamic color blending[\[9\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=ToolbarItemPlacement%20become%20really%20important%20while,applies%20the%20glassProminent%20button%20style).

### Morphing Transitions

When presenting content from toolbar buttons (e.g., opening a sheet), the new matchedTransitionSource() and navigationTransition(.zoom) APIs create morphing transitions where the toolbar button appears to expand into the sheet or navigation destination. This is particularly effective for partial‑height sheets (described below)[\[15\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=Another%20update%20in%20iOS%2026,visually%20connected%20to%20its%20source).

## Modals and Sheets

Partial height sheets adopt Liquid Glass automatically when using .presentationDetents(\[.medium, .large\]) or similar. To maintain the glass effect, avoid customizing the presentation background; instead rely on the default sheet style[\[16\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=). When the sheet expands to full height, it becomes opaque to provide a focused environment[\[17\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=When%20the%20sheet%20is%20expanded,sides%20and%20bottom%20of%20the). If the sheet contains a Form, call .scrollContentBackground(.hidden) to hide the default form background and let the sheet’s glass show through[\[18\]](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/#:~:text=Form%20views%2C%20like%20lists%2C%20provide,Form). For nested NavigationStack destinations within the sheet, use .containerBackground(.clear, for: .navigation) to avoid covering the glass[\[19\]](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/#:~:text=For%20example%2C%20we%20might%20have,containerBackground%28.clear%2C%20for%3A%20.navigation).

## Custom Views and Glass Effects

### Applying glassEffect

Developers can apply the glass look to custom controls using .glassEffect(). This modifier has several variants:

* .regular creates an opaque glass surface; .clear results in nearly transparent glass suitable for minimal overlays[\[20\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=The%20SwiftUI%20framework%20introduced%20the,on%20the%20content%20behind%20it).

* .interactive() toggles between interactive (clickable) and inert states; interactive glass darkens slightly on press[\[21\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=There%20are%20three%20options%20at,turn%20off%20the%20glass%20effect).

* .tint() applies a custom accent color; the system generates appropriate tones based on the brightness of underlying content[\[22\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=The%20second%20parameter%20on%20the,using%20any%20shape%20you%20need).

Example: create a floating button with glass effect:

Button(action: {}) {  
    Image(systemName: "plus")  
        .font(.title)  
}  
.buttonStyle(.plain)  
.glassEffect(.regular.interactive())  
.padding()

### Grouping Glass Components

Applying glassEffect to multiple buttons individually causes each control to appear as separate glass surfaces. Use GlassEffectContainer to group them. Wrapping items inside a GlassEffectContainer merges them into a single continuous glass shape, allowing them to reflect each other[\[23\]](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/#:~:text=You%20can%20apply%20the%20glassEffect,of%20views%20with%20the%20GlassEffectContainer). When elements are separated by space but should still be perceived as one shape (e.g., segmented control), use the glassEffectUnion(id:namespace:) modifier on each element with the same id; the framework then draws them as a single glass piece across a distance[\[24\]](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/#:~:text=var%20body%3A%20some%20View%20,interactive).

## Design Principles and Accessibility

Apple’s design guidelines emphasise that Liquid Glass should be used sparingly: only navigation controls, floating buttons and overlays should adopt glass; lists, grids and main content should remain opaque[\[25\]](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/#:~:text=The%20idea%20of%20Liquid%20Glass,can%20see%20in%20this%20video). When tinting glass surfaces, choose a single accent color for the entire scene; multiple tinted controls can appear inconsistent because tints propagate through the translucent surface[\[26\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=17%3A21). The system automatically supports **Reduce Transparency** and **Increase Contrast** accessibility settings: when these are enabled, the glass effect becomes more solid or uses higher contrast colors[\[27\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=when%20three%20conditions%20are%20met%3A,tinting%20emphasizes%20physicality%20and%20improves).

## Migrating from Older Patterns

Experienced iOS developers must adjust existing UI structures to adopt Liquid Glass:

1. **Remove custom blur backgrounds**: previously, developers used VisualEffectBlur or custom backgrounds for toolbars and tab bars. In iOS 26 these should be removed; rely on the system’s automatic glass.

2. **Replace embedded search bars**: search bars were often embedded in lists or toolbars; now call .searchable on the navigation container and trust the system for placement[\[2\]](https://developer.apple.com/videos/play/wwdc2025/256/#:~:text=Search%20is%20now%20bottom%20aligned,it%20more%20ergonomic%20to%20reach).

3. **Use new tab API**: the old .tabItem style still works but does not support search roles or automatic minimization. Adopt Tab with role: parameter and tabBarMinimizeBehavior for advanced interactions[\[7\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=var%20body%3A%20some%20View%20,%2F%2F%20content).

4. **Update forms and sheets**: ensure forms use .scrollContentBackground(.hidden) and specify detents; remove presentationBackground customization[\[18\]](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/#:~:text=Form%20views%2C%20like%20lists%2C%20provide,Form).

5. **Adopt new toolbar and spacer APIs**: restructure toolbars with icons \+ text and ToolbarSpacer to group items[\[14\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=As%20you%20can%20see%20in,both%20images%20and%20text%20labels).

6. **Experiment with morphing transitions and glass groups**: take advantage of matchedTransitionSource, navigationTransition, GlassEffectContainer and glassEffectUnion for modern interactions[\[15\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=Another%20update%20in%20iOS%2026,visually%20connected%20to%20its%20source)[\[24\]](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/#:~:text=var%20body%3A%20some%20View%20,interactive).

## Conclusion

iOS 26’s Liquid Glass design introduces a dynamic, tactile layer that floats above content. By recompiling with Xcode 26, default SwiftUI components automatically adopt this style. Developers should embrace the new search patterns—placing search at the bottom of navigation stacks and using dedicated search tabs—and should restructure toolbars and tab bars with the new APIs. Applying glassEffect to custom controls, using GlassEffectContainer for grouping, and respecting accessibility settings ensures a cohesive experience. Combined with SwiftUI 6’s performance and macro improvements[\[5\]](https://useyourloaf.com/blog/wwdc-2025-viewing-guide/#:~:text=There%E2%80%99s%20work%20to%20be%20done,apps%20for%20the%20new%20design), these changes empower developers to build modern, immersive interfaces aligned with Apple’s latest design philosophy.

---

[\[1\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=sophisticated%20system%2C%20working%20together,which%20is%20permanently%20transparent%20and) [\[3\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=17%3A03) [\[26\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=17%3A21) [\[27\]](https://developer.apple.com/videos/play/wwdc2025/219/#:~:text=when%20three%20conditions%20are%20met%3A,tinting%20emphasizes%20physicality%20and%20improves) Meet Liquid Glass \- WWDC25 \- Videos \- Apple Developer

[https://developer.apple.com/videos/play/wwdc2025/219/](https://developer.apple.com/videos/play/wwdc2025/219/)

[\[2\]](https://developer.apple.com/videos/play/wwdc2025/256/#:~:text=Search%20is%20now%20bottom%20aligned,it%20more%20ergonomic%20to%20reach) What’s new in SwiftUI \- WWDC25 \- Videos \- Apple Developer

[https://developer.apple.com/videos/play/wwdc2025/256/](https://developer.apple.com/videos/play/wwdc2025/256/)

[\[4\]](https://www.infoworld.com/article/4005538/apple-rolls-out-swift-swiftui-and-xcode-updates.html#:~:text=1,7) Apple rolls out Swift, SwiftUI, and Xcode updates | InfoWorld

[https://www.infoworld.com/article/4005538/apple-rolls-out-swift-swiftui-and-xcode-updates.html](https://www.infoworld.com/article/4005538/apple-rolls-out-swift-swiftui-and-xcode-updates.html)

[\[5\]](https://useyourloaf.com/blog/wwdc-2025-viewing-guide/#:~:text=There%E2%80%99s%20work%20to%20be%20done,apps%20for%20the%20new%20design) WWDC 2025 Viewing Guide

[https://useyourloaf.com/blog/wwdc-2025-viewing-guide/](https://useyourloaf.com/blog/wwdc-2025-viewing-guide/)

[\[6\]](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/#:~:text=the%20new%20SwiftUI%20modifier%20searchToolbarBehavior,the%20number%20of%20toolbar%20items) [\[11\]](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/#:~:text=content%20types%20introduced%20in%20iOS,kind%2C%20and%20ToolbarSpacer) SwiftUI Search Enhancements in iOS and iPadOS 26

[https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/](https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/)

[\[7\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=var%20body%3A%20some%20View%20,%2F%2F%20content) [\[8\]](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/#:~:text=.tabViewStyle%28.sidebarAdaptable%29%20.tabViewBottomAccessory%20%7B%20Button%28,) Glassifying tabs in SwiftUI | Swift with Majid

[https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/](https://swiftwithmajid.com/2025/06/24/glassifying-tabs-in-swiftui/)

[\[9\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=ToolbarItemPlacement%20become%20really%20important%20while,applies%20the%20glassProminent%20button%20style) [\[14\]](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/#:~:text=As%20you%20can%20see%20in,both%20images%20and%20text%20labels) Glassifying toolbars in SwiftUI | Swift with Majid

[https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/)

[\[10\]](https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/#:~:text=With%20the%20introduction%20of%20the,an%C2%A0expanded%C2%A0and%C2%A0compact%C2%A0state%20to%20prioritize%20screen%20content) Adapting Search to the Liquid Glass Design System

[https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/](https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/)

[\[12\]](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/#:~:text=In%20the%20health%20app%20example,role) [\[13\]](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/#:~:text=ZStack%28alignment%3A%20.bottomTrailing%29%20,contents) Exploring tab bars on iOS 26 with Liquid Glass – Donny Wals

[https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)

[\[15\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=Another%20update%20in%20iOS%2026,visually%20connected%20to%20its%20source) [\[16\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=) [\[17\]](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/#:~:text=When%20the%20sheet%20is%20expanded,sides%20and%20bottom%20of%20the) Presenting Liquid Glass sheets in SwiftUI on iOS 26

[https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/)

[\[18\]](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/#:~:text=Form%20views%2C%20like%20lists%2C%20provide,Form) [\[19\]](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/#:~:text=For%20example%2C%20we%20might%20have,containerBackground%28.clear%2C%20for%3A%20.navigation) SwiftUI Liquid Glass sheets with NavigationStack and Form

[https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/](https://nilcoalescing.com/blog/LiquidGlassSheetsWithNavigationStackAndForm/)

[\[20\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=The%20SwiftUI%20framework%20introduced%20the,on%20the%20content%20behind%20it) [\[21\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=There%20are%20three%20options%20at,turn%20off%20the%20glass%20effect) [\[22\]](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/#:~:text=The%20second%20parameter%20on%20the,using%20any%20shape%20you%20need) Glassifying custom SwiftUI views | Swift with Majid

[https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/](https://swiftwithmajid.com/2025/07/16/glassifying-custom-swiftui-views/)

[\[23\]](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/#:~:text=You%20can%20apply%20the%20glassEffect,of%20views%20with%20the%20GlassEffectContainer) [\[24\]](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/#:~:text=var%20body%3A%20some%20View%20,interactive) Glassifying custom SwiftUI views. Groups | Swift with Majid

[https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/](https://swiftwithmajid.com/2025/07/23/glassifying-custom-swiftui-views-groups/)

[\[25\]](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/#:~:text=The%20idea%20of%20Liquid%20Glass,can%20see%20in%20this%20video) Designing custom UI with Liquid Glass on iOS 26 – Donny Wals

[https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
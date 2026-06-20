## 2026-05-24 - Contextual Tooltips and Loading States
**Learning:** Adding dynamic `.help()` text that incorporates contextual variables (like a drive's name) significantly improves accessibility, especially for generic actions like "Show Details" mapped to an `info.circle` icon. Additionally, explaining *why* an action is disabled (e.g. "Select an installation to edit") via tooltips is much more user-friendly than a silently disabled button. Replacing a static icon with a `ProgressView` in a toolbar button effectively communicates background activity.
**Action:** When creating tables or lists with inline actions, always incorporate the item's name/identifier into the tooltip. For disabled buttons, use dynamic text in `.help()` to explain the requirement to the user.

## 2026-05-25 - Dynamic Tooltips on Disabled Buttons
**Learning:** Using conditional ternary operators for `.help()` modifiers (e.g., `.help(isInvalid ? "Reason it is disabled" : "Default tooltip")`) on disabled buttons provides a significantly better user experience than leaving them blank, as it guides the user on how to proceed.
**Action:** Always provide a default tooltip text for the enabled state when implementing conditional `.help()` text for disabled buttons to avoid rendering empty tooltip windows on macOS.

## 2026-05-26 - LabeledContent for macOS Forms
**Learning:** For macOS Forms, standard `TextField` views without visible labels may result in poor layout and lack VoiceOver context.
**Action:** Always wrap inputs in `LabeledContent("Label Text") { ... }` and use `.labelsHidden()` on the inner control to provide proper accessibility associations and conform to standard macOS layout conventions.

## 2026-05-27 - Actionable Empty States
**Learning:** Utilizing `ContentUnavailableView` action closures to provide explicit, context-aware calls-to-action (like "Refresh" or "Add Server") directly within the empty state significantly improves discoverability compared to relying solely on generic toolbar buttons that may be physically distant from the message.
**Action:** Always prefer the `ContentUnavailableView` initializer with the `actions` closure to place primary contextual actions inline when designing empty, uninitialized, or error states.

## 2026-05-28 - VoiceOver Element Grouping and Hidden Images
**Learning:** Screen readers will sometimes read individual components of a custom metric or tile separately, and announce generic system icon names that don't add context, degrading the experience. Grouping elements correctly makes VoiceOver read the title and value as a cohesive phrase.
**Action:** Always add `.accessibilityElement(children: .combine)` to `VStack` components acting as unified metrics, and use `.accessibilityHidden(true)` on decorative or redundant status images.

## 2026-05-28 - Informative Image Accessibility
**Learning:** While decorative images should use `.accessibilityHidden(true)`, status icons that convey meaning (like "warning" or "offline") should never be hidden. Hiding them removes critical context for VoiceOver users.
**Action:** Use `.accessibilityLabel()` with descriptive text (e.g., the status name or a summary like "Issues detected") on system images that convey state, ensuring assistive technologies narrate the visual meaning rather than the raw SF Symbol name.

## 2026-05-29 - Keyboard Navigation and Focus Flow in Forms
**Learning:** Sequential text fields in macOS forms lack native Enter/Return key progression by default. Adding `textContentType` is helpful for autofill, but true keyboard accessibility requires explicitly linking the fields via a bounded `@FocusState` enum and listening to `.onSubmit` on the parent form to shift focus programmatically.
**Action:** When implementing multi-input Forms (like credentials or server settings), define an enum mapping the fields, apply `.focused()` and `.textContentType()`, and use `.onSubmit` to advance the user automatically down the form, executing the save action only on the final field.

## 2026-05-29 - Add missing accessibility labels to icon-only buttons
**Learning:** Icon-only toolbar buttons created natively without explicit `.accessibilityLabel()` modifiers may lack context for VoiceOver, reducing usability for screen reader users. The `Label` view might try to provide this when using `.labelStyle(.iconOnly)`, but when mixed with other states like `ProgressView`, the explicit label ensures clear context.
**Action:** Always add `.accessibilityLabel("...")` to icon-only buttons (`.labelStyle(.iconOnly)`), particularly when they reside in toolbars or handle state transitions.

## 2026-05-27 - Inline Validation Feedback and Styling
**Learning:** Clearing form validation error messages dynamically (e.g., via `.onChange`) as the user begins to correct their input provides a significantly better, more responsive user experience than waiting for the next submission attempt. Furthermore, using a consistent, visually distinct error component (like `ErrorPanel`) instead of raw text improves readability and aligns with the broader design system.
**Action:** When implementing form validation, attach `.onChange` handlers to the input fields to clear stale error states immediately, and utilize standard error UI components to display the feedback with appropriate animations.

## 2026-05-29 - Explicit VoiceOver Labels for Hidden Form Fields
**Learning:** When using `LabeledContent` with macOS forms, hiding the inner field labels via `.labelsHidden()` removes visual clutter but also strips VoiceOver context if the field is initialized with an empty string. VoiceOver may read the prompt or just "text field", confusing users.
**Action:** Always provide an explicit string label to `TextField` and `SecureField` initializers inside `LabeledContent`, even when using `.labelsHidden()`, to guarantee assistive technologies have correct context.
## 2026-05-30 - Explicit VoiceOver Labels for Hidden Pickers
**Learning:** Similar to `TextField`, when using `LabeledContent` with macOS forms, hiding the inner field labels via `.labelsHidden()` removes visual clutter but also strips VoiceOver context if the inner `Picker` is initialized with an empty string label `""`. VoiceOver may read the prompt or generic fallback, confusing users.
**Action:** Always provide an explicit string label to `Picker` initializers inside `LabeledContent`, even when using `.labelsHidden()`, to guarantee assistive technologies have correct context without adding visual clutter.
## 2026-05-30 - Contextual Empty States for Global Variables
**Learning:** When an empty state in a detail view relies on a global variable (e.g. "Choose an installation from the sidebar"), it creates a confusing experience if that global collection is also empty (meaning they can't actually choose one). Conditionally tailoring the empty state based on the global collection's state improves usability.
**Action:** Before rendering "Select an X" empty states, check if X exists globally. If it doesn't, pivot the empty state to "Add an X" to guide the user toward the correct first step.
## 2026-06-03 - Avoid `accessibilityElement(children: .combine)` on visually grouped structural views
**Learning:** VoiceOver reads concatenated string segments natively merged by `.combine` continuously and sequentially (e.g. "Basement NAS Healthy - 4 drives"). Without punctuation inside the inner child labels, there are no natural pauses, which makes listening confusing for screen-reader users, especially on data-heavy tables or rows.
**Action:** When grouping visual elements (like `HStack` or `VStack`), use `.accessibilityElement(children: .ignore)` on the container and apply a carefully formatted explicit `.accessibilityLabel` strings (like `Basement NAS, Status: Healthy, 4 drives`) that use commas to inject natural pauses for VoiceOver.
## 2026-06-05 - Dynamic Setting Feedback and Shortcut Discovery
**Learning:** Stale validation or feedback messages (e.g. "WebDAV saved") that persist while the user is actively changing the input fields create a disjointed experience. Additionally, macOS doesn't always automatically inject keyboard shortcuts into tooltips for custom icon-only buttons.
**Action:** Always clear feedback/validation messages on input change (using `.onChange`) and explicitly include keyboard shortcut symbols (e.g., `(⌘R)`) in the `.help()` modifier strings to improve discoverability.

## 2026-05-31 - Actionable Empty States in Detail Views
**Learning:** When a global collection is empty, providing an actionable empty state (e.g., 'Add Installation' button) in the central detail view significantly improves UX, even if the sidebar already has one. Users naturally look at the main content area first.
**Action:** When designing detail views that depend on a global list, if the list is empty, always include an explicit action button within the `ContentUnavailableView` to help the user resolve the empty state directly.
## 2026-05-27 - Explicit Keyboard Shortcuts in Tooltips
**Learning:** macOS requires explicit keyboard shortcut symbols (e.g., `(⌘E)`) inside `.help()` strings for custom icon-only buttons in order to display the shortcut visually in the tooltip. While VoiceOver handles `.accessibilityLabel()` smoothly, relying only on `.keyboardShortcut()` won't automatically inject the hint into the `.help()` tooltip for custom styles like icon-only labels.
**Action:** When creating icon-only buttons with keyboard shortcuts, always include the shortcut explicitly in the `.help()` modifier text, and keep the shortcut out of the `.accessibilityLabel()`.

## 2026-05-27 - Double Click Accessibility in Tables
**Learning:** Table rows implementing `onTapGesture(count: 2)` need a hover effect to visually indicate to macOS users that the row is interactable. Changing the cursor using `NSCursor.pointingHand.push()` in `.onHover` is unsafe and can lead to permanent cursor leaks or crashes if the view is destroyed while hovered.
**Action:** Use a `@State` variable with `.onHover` to toggle a subtle background highlight color or opacity instead of manipulating global cursor state.
## 2026-06-10 - Explicit Accessibility Labels for ProgressViews
**Learning:** Standard indeterminate `ProgressView` instances without explicit text parameters lack clear context for VoiceOver users, leading to generic "progress indicator" announcements.
**Action:** Always add an explicit `.accessibilityLabel(...)` modifier to `ProgressView` instances that are used to indicate loading or refreshing states, especially inside buttons or lists.

## 2026-06-06 - Explicit Accessibility Labels for Indeterminate Loaders
**Learning:** Even when `ProgressView` instances are initialized with a string title (e.g., `ProgressView("Refreshing...")`), explicitly attaching `.accessibilityLabel` ensures deterministic and robust VoiceOver behavior, preventing fallback inference. Adding `accessibilityLabel` safely supplements SwiftUI’s default behavior for screen readers without any visual side effects.
**Action:** Always include `.accessibilityLabel("State")` when defining indeterminate `ProgressView` components, regardless of whether a visual title is provided, ensuring uniform a11y context across views.
## 2026-06-12 - Hiding Redundant Images in Status Labels
**Learning:** When using standard `Label` views with system images to convey status, VoiceOver may redundantly read both the image name and the text, resulting in a suboptimal screen reading experience.
**Action:** Instead of relying on `Label(text, systemImage:)` for dynamic status presentation, use an `HStack` where the `Image` uses `.accessibilityHidden(true)` and the `Text` provides the status, ensuring VoiceOver reads the status cleanly and exactly once.
## 2026-06-15 - Consistent Accessibility Grouping on Conditional Views
**Learning:** When using conditional views (e.g., `if isRefreshing else ...`) representing the same conceptual UI element, ensure all mutually exclusive branches provide equivalent and consistent accessibility groupings and labels to prevent erratic VoiceOver behavior.
**Action:** Always apply `.accessibilityElement(children: .ignore)` and an explicit `.accessibilityLabel(...)` to both branches of an `if-else` view group when they swap out visual components representing identical semantic states.

## 2026-06-17 - Contextual Tooltips on Truncated Metric Tiles
**Learning:** Metric tiles often have fixed or constrained layouts using `.lineLimit(1)` and `.minimumScaleFactor`. While this keeps the grid visually neat, large values or titles can truncate on smaller screens. Adding a native `.help()` tooltip ensures the user can always hover to see the full context without sacrificing the clean visual layout.
**Action:** Always add `.help("\(title): \(value)")` to metric tile components that use line limits, matching the structure of their `.accessibilityLabel` to maintain consistency for both sighted and VoiceOver users.
## 2026-05-27 - [Sidebar Action Bar Tooltips]
**Learning:** Adding clear accessibility labels and help text for interactive elements improves usability. Disabled buttons should explain why they are disabled using help tooltips.
**Action:** When buttons are disabled because an item is not selected, update the help tooltip to explain this condition.

## 2026-05-27 - [Disabled Button Tooltips]
**Learning:** Tooltips for disabled buttons are only effective if they explain the exact missing requirement (e.g., "A valid URL is required") rather than just restating the action ("Save"). This gives users clear direction on how to fix the issue.
**Action:** When conditionally disabling a button based on state/validation, bind the `help` or `tooltip` modifier to provide dynamic text explaining the specific unfulfilled condition.
## 2026-05-27 - [Interactive Row Tooltips]
**Learning:** Interactive rows (like double-clickable ones) should provide visual cues like hover effects to indicate interactivity.
**Action:** When adding double-click interactions, ensure `.onHover` adds a subtle background highlight and a `.help` modifier provides a tooltip indicating the action (e.g., "Double-click for details").

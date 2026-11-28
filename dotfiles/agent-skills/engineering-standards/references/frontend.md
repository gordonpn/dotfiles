# Frontend accessibility profile

**Trigger:** User-facing web content or interactive UI changes.

- Target [WCAG 2.2 Level AA](https://www.w3.org/TR/WCAG22/) where feasible and consistent with project scope; use semantic HTML and native controls before custom ARIA widgets.
- Follow [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) when building custom interactive elements. Respect keyboard navigation, focus visibility and order, labels, error identification, contrast, reduced motion, and readable status updates.
- Validate with accessibility tooling and meaningful manual keyboard checks; automated checks do not establish full WCAG conformance. Preserve existing design systems and test patterns where possible.
- Avoid adding large new UI frameworks or component libraries solely to satisfy these principles.
- **UI Verification Loop:** When modifying user interfaces, follow the complete interaction loop: read code -> understand requirements -> modify code -> run automated tests -> launch application -> interact with UI (via Playwright or browser tools) -> verify actual behavioral output across edge cases (empty input submissions, rapid double submission, pagination limits, and state preservation across page reloads).

# Internationalization

Internationalization separates user-facing content from application logic so that the same feature can support multiple locales.

## Message Design

- Store messages in locale-specific resource files using stable semantic keys.
- Use placeholders for dynamic values instead of constructing translated sentences in code.
- Include translator context for ambiguous labels, dates, quantities, and domain terms.
- Keep source messages concise and avoid encoding layout, punctuation, or grammar assumptions in keys.

## Locale Selection

Resolve the locale in a predictable order, such as an explicit user preference, a request preference, then an application default. Persist an explicit user choice. Use a documented fallback locale when a translation is missing.

## Formatting

Use locale-aware platform or library formatters for dates, times, numbers, currency, lists, relative time, and plural forms. Pass structured values to formatters rather than formatting strings manually.

## Implementation Checklist

- Load only the translation resources needed by the current locale and feature.
- Test pluralization, interpolation, missing-message fallback, and locale changes.
- Verify both left-to-right and right-to-left layouts if supported.
- Keep language, region, and formatting preferences independent when the product requires it.

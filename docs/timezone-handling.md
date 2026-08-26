# Timezone Handling

Timezone handling should preserve an exact instant for machine processing while presenting time in the user’s intended zone.

## Storage Model

- Store timestamps as UTC instants in persistent storage and messages.
- Use an unambiguous standard such as ISO 8601 with an offset for API payloads.
- Store an IANA timezone identifier when a feature needs to preserve the intended local zone, such as a scheduled event.
- Do not store a local date-time without its timezone when it represents a real-world instant.

## Input and Display

When collecting a scheduled time, ask for or infer the intended timezone and show it back to the user before saving. Convert the stored instant to the viewer’s selected or detected timezone at display time. Label the displayed zone where ambiguity matters.

## Daylight Saving Time

Use a timezone-aware library for conversion and recurrence calculations. Validate local times that are skipped or repeated during daylight-saving transitions, and require an explicit resolution when needed.

## Testing

Test conversions across multiple zones, date boundaries, daylight-saving transitions, serialization boundaries, and user preference changes. Include fixed test instants so results are deterministic.

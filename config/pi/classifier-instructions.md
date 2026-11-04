# Classifier model

For typed classification in codemode, use Jev with
`models.classify(@classifierModel@, { state, questions })`.
Check `stopReason` before using `answers`. If credentials are missing or the
request fails, report the error instead of switching providers. This selects a
classifier, not the chat model.

# add-society-documents-bucket

Provision a new R2 bucket `cgrs-documents-prod` for Society Documents (minutes, agendas, financial records) via OpenTofu, with GET/HEAD-only CORS and a multipart-abort lifecycle rule. Credentials are a dedicated, dashboard-created R2 token scoped to this bucket — isolated from the images token. Pairs with the app-side `add-society-documents` change in the root openspec.

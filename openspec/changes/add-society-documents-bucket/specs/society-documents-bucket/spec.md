## ADDED Requirements

### Requirement: Dedicated society-documents R2 bucket

The system SHALL provision an R2 bucket named `cgrs-documents-prod` via OpenTofu, declared as an entry in the `r2_buckets` list consumed by `modules/r2-bucket`. The bucket SHALL be separate from `cgrs-images-prod` and `cgrs-state-storage`.

#### Scenario: Bucket created on apply

- **WHEN** `tofu apply` runs with `cgrs-documents-prod` present in `r2_buckets`
- **THEN** an R2 bucket named `cgrs-documents-prod` exists in the Cloudflare account
- **AND** the existing `cgrs-images-prod` bucket and its configuration are unchanged

### Requirement: GET/HEAD-only CORS

The bucket SHALL be configured with CORS rules permitting only `GET` and `HEAD` methods for the web-app origins. The bucket SHALL NOT permit `PUT` via CORS, because uploads are proxied server-side through the API rather than issued directly from the browser.

#### Scenario: Presigned GET from the web app is allowed

- **WHEN** the web app (an approved origin) fetches a presigned GET URL for an object in the bucket
- **THEN** the CORS configuration permits the GET request

#### Scenario: Browser PUT is not permitted by CORS

- **WHEN** the CORS configuration is inspected
- **THEN** `PUT` is not among the allowed methods

### Requirement: Abort stale multipart uploads

The bucket SHALL have a lifecycle rule that aborts incomplete multipart uploads after 1 day, to reclaim fragments orphaned by failed proxied uploads. The lifecycle capability SHALL be expressed as an optional variable on `modules/r2-bucket` so that buckets without a lifecycle rule are unaffected.

#### Scenario: Orphaned multipart upload is reclaimed

- **WHEN** a multipart upload to the bucket is started but not completed, and more than 1 day passes
- **THEN** the lifecycle rule aborts the incomplete multipart upload

#### Scenario: Other buckets are unaffected

- **WHEN** a bucket is declared without lifecycle rules (default empty)
- **THEN** no `cloudflare_r2_bucket_lifecycle` resource is created for it and its plan shows no diff

### Requirement: Credentials supplied by a dedicated out-of-band token

The bucket SHALL be accessed by the API using a dedicated R2 API token scoped to `cgrs-documents-prod` only, distinct from the token used for `cgrs-images-prod`. The token SHALL NOT be managed by Terraform; its keys SHALL be supplied to the API as the secrets `R2_DOCUMENTS_ACCESS_KEY_ID` and `R2_DOCUMENTS_SECRET_ACCESS_KEY`. The token scope and secret names SHALL be documented in the environment README.

#### Scenario: Images-token leak cannot reach documents

- **WHEN** the `cgrs-images-prod` token credentials are compromised
- **THEN** those credentials do not grant access to `cgrs-documents-prod`, because the documents bucket uses a separate, bucket-scoped token

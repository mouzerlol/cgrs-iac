## ADDED Requirements

### Requirement: Communities are isolated by bucket, not by key convention

Each community SHALL have its own public bucket, its own content domain, and its own private working bucket. Isolation SHALL be a property of the infrastructure and SHALL NOT depend on the application constructing keys correctly.

Bucket declarations SHALL be shaped so that provisioning an additional community is an added entry in the environment configuration rather than new module or resource work.

#### Scenario: Cross-tenant read is impossible

- **WHEN** a key belonging to one community is requested from another community's content domain
- **THEN** it is not found, because the object does not exist in that bucket

#### Scenario: A second community is a declarative addition

- **WHEN** another community needs published content
- **THEN** it is added as a further entry using the same module, with no new resource types

### Requirement: A public bucket serves published blog artifacts

A bucket `cgrs-blog-prod` SHALL be provisioned with public read access enabled, holding only published blog artifacts: the manifest, per-post body documents, and published imagery.

Public read access SHALL be an explicit, declared property of this bucket. It SHALL NOT be enabled by default for any other bucket in the estate.

#### Scenario: Objects readable without credentials

- **WHEN** an anonymous client requests a published object by its key
- **THEN** the object is returned without any credential

#### Scenario: Other buckets remain private

- **WHEN** the configuration is applied
- **THEN** `cgrs-images-prod` and `cgrs-documents-prod` remain private and their provisioning is unchanged

### Requirement: A custom domain fronts the public bucket

`content.cgrs.co.nz` SHALL be bound to `cgrs-blog-prod` as a custom domain, with the DNS record that binding requires, so that published artifacts are served over a stable hostname on the society's own domain and cached at Cloudflare's edge.

The bucket's default R2 endpoint SHALL NOT be the addressing the application depends on.

#### Scenario: Content served from the society domain

- **WHEN** a published object is requested at `https://content.cgrs.co.nz/<key>`
- **THEN** it is returned, served from Cloudflare's edge

#### Scenario: Applications address the custom domain

- **WHEN** application configuration references published content
- **THEN** it uses the custom domain rather than the account-specific R2 endpoint

### Requirement: A private bucket holds source and unpublished content

A bucket `cgrs-blog-src-prod` SHALL be provisioned without public access, holding source markdown, revision archives, and unpublished assets. It SHALL be reachable only with S3 credentials.

#### Scenario: Private bucket rejects anonymous reads

- **WHEN** an anonymous client requests any object in `cgrs-blog-src-prod`
- **THEN** the request is refused

#### Scenario: Working content has a home outside the public bucket

- **WHEN** the application stores a draft's markdown or an unpublished asset
- **THEN** a private bucket exists for it, so nothing unpublished need ever be written to the public bucket

### Requirement: The shared bucket module gains optional public access and domain binding

`modules/r2-bucket` SHALL accept optional public-access and custom-domain configuration, implemented as count-guarded resources that default to disabled so existing bucket declarations are unaffected.

The module SHALL output the public hostname of any bucket configured with a custom domain.

#### Scenario: Existing buckets unaffected by the new variables

- **WHEN** the module is upgraded and a plan is produced for the existing buckets
- **THEN** no change is proposed for `cgrs-images-prod` or `cgrs-documents-prod`

#### Scenario: Hostname available to consumers

- **WHEN** a bucket declares a custom domain
- **THEN** the module outputs that hostname for use in application configuration

### Requirement: CORS permits reads only

The public bucket SHALL declare CORS allowing GET and HEAD from the web application origins used by the existing buckets. It SHALL NOT allow PUT, because all writes are performed server-side by the API.

The private bucket SHALL declare no CORS rules, since no browser ever addresses it directly.

#### Scenario: Browser write refused

- **WHEN** a browser attempts a direct PUT against the public bucket
- **THEN** it is not permitted by the CORS configuration

#### Scenario: Origins stay consistent

- **WHEN** the web application origin list changes
- **THEN** the blog bucket's origin list is maintained alongside the existing buckets' lists

### Requirement: Lifecycle hygiene on both buckets

Both buckets SHALL declare a lifecycle rule aborting incomplete multipart uploads after one day, matching the existing bucket configuration.

#### Scenario: Orphaned multipart fragments reclaimed

- **WHEN** an upload is interrupted and leaves incomplete multipart fragments
- **THEN** they are aborted and reclaimed after one day

### Requirement: Credentials are supplied out of band

Bucket credentials SHALL NOT be managed by OpenTofu. A bucket-scoped R2 API token covering both new buckets SHALL be created in the Cloudflare dashboard, and its keys stored as `cgrs-api` secrets, matching existing practice for the images and documents buckets.

The environment documentation SHALL record which secrets carry those keys and SHALL state the public-read posture of the blog bucket explicitly.

#### Scenario: No credential in state

- **WHEN** the OpenTofu state is inspected
- **THEN** it contains no R2 access key or secret

#### Scenario: Posture is documented, not implicit

- **WHEN** an operator reads the environment documentation
- **THEN** it states that `cgrs-blog-prod` is world-readable by design and that unpublished content must never be written to it

### Requirement: Buckets declared without optional configuration stay minimal

A bucket declared with neither CORS, lifecycle, public access, nor a custom domain SHALL result in only the bucket resource being created, and that bucket SHALL be private.

#### Scenario: Minimal declaration creates one resource

- **WHEN** a bucket is declared with no optional configuration
- **THEN** only the bucket resource is created and it is private

#### Scenario: Optional configuration is scoped to the declaring bucket

- **WHEN** one bucket declares public access and a custom domain
- **THEN** those resources are created for that bucket alone and no other bucket's plan changes

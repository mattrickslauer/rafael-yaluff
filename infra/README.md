# yaluff.art on AWS

Private S3 bucket → CloudFront (OAC) → `yaluff.art`, with `www.yaluff.art` 301-redirecting
to the apex. CloudFormation stack `rafael-yaluff` in account 821135790223, us-east-1.

- **Every push to `main`** runs `.github/workflows/deploy.yml`, which syncs the repo root
  to the bucket and invalidates the cache (`infra/publish.sh`). Edit a file on GitHub,
  commit to main, and it's live in a minute or two.
- **Infrastructure changes** (`infra/stack.yaml`) are not applied by CI. Run
  `CERT_ARN=arn:aws:acm:us-east-1:821135790223:certificate/3bb0f3bc-5dec-4254-af88-9eaee1e8f3e6 ./infra/deploy.sh`
  with admin credentials.

## DNS (Namecheap → Advanced DNS)

| Type | Host | Value |
|---|---|---|
| CNAME | `_ad3f938979de9a146e151ff981f7a6ac` | `_4c5e0e9129312cef5e99a6c885a5c108.wzccmgtwzk.acm-validations.aws.` |
| CNAME | `_d0e4805c35bd05eae95598f07b1a027d.www` | `_a368449a153404d4c79fd372ed67d290.wzccmgtwzk.acm-validations.aws.` |
| ALIAS | `@` | the stack's `DistributionDomain` output |
| CNAME | `www` | the stack's `DistributionDomain` output |

Leave the two `_…` validation CNAMEs in place forever — ACM renews the certificate
through them.

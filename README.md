\# LAWVM



LAWVM is a standalone deterministic machine-law execution layer.



It is built for people who need policy decisions to be local-first, reproducible, inspectable, and verifiable.



\## What LAWVM does



LAWVM lets you:



\- load a policy bundle from disk

\- verify whether that bundle is signed by an expected signer

\- evaluate a request against deterministic policy rules

\- return a stable decision result such as ALLOW or DENY

\- run reproducible selftests to confirm the engine is working correctly



\## What problem it solves



Most policy logic is buried inside applications, services, or ad hoc scripts. That creates drift, weak auditability, and unclear trust boundaries.



LAWVM separates policy evaluation into a standalone deterministic CLI workflow so decisions can be tested, verified, and trusted independently.



\## Who it is for



LAWVM is for:



\- developers building governed software

\- security and policy researchers

\- operators who need explicit local policy decisions

\- system designers building deterministic infrastructure

\- teams that want policy bundles and request inputs to remain local on disk



\## How users provide their own policies and requests



LAWVM is currently a standalone local CLI tool.



Users do not upload policy to a hosted service. Instead, they:



1\. create a policy bundle JSON file

2\. create one or more request JSON files

3\. optionally sign the policy bundle

4\. run LAWVM against those files locally



Example project layout:



```text

my-lawvm-project/

&#x20; policy\_bundle.json

&#x20; request\_allow.json

&#x20; request\_deny.json

&#x20; policy\_bundle.sig

&#x20; allowed\_signers


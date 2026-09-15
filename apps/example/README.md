# The example: controlled unclassified information

The application that measures every adapter. It is a document store under the marking rules of 32 CFR Part 2002 and the controls of the CUI Registry. `docs/example.md` §3 states its thirteen rules, and `docs/example.md` §4 holds its scenarios. The domain, its contexts, and every scenario live here. A thin application binds one adapter to it and adds only what that adapter needs. This package has no application callback and starts nothing.

The package's own tests cover the contexts under `Mediate.Test.Fake`. The scenarios run in each thin application, under the adapter it binds, and never here. `Example` and the moduledocs say what each module does.

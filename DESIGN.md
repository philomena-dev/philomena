Each route which does something performs either:
1. a single operation, or
2. inseparable operations connecting a group of resources

Individual controllers should have in common for all functions they define:
1. single operations on a single resource, or
2. inseparable operations connecting a group of resources

Controller functions should:
1. Perform basic sufficiency checks and fail early if possible
2. Delegate any necessary authentication and authorization responsibilities to the context
3. Delegate the final action to the context

Context functions should:
1. Perform a single operation, or a transaction over inseparable operations connecting a group of resources
2. Document preconditions needed to ensure composability and interoperability with controllers and/or other contexts
3. Following the preconditions in (2), assume any necessary level of authentication and authorization

Schemas should:
1. Define a strict structure for the data they hold
2. Define validations and functions necessary for model construction

Views should:
1. Call context functions to collect auxiliary information displayed to the current route
2. Define ad-hoc data structures as needed to hold information displayed by functional components

Functional components should:
1. Present information passed in from views

---

A context works with single resources, but you might have fairly complicated interactions between multiple resources --
not just something simple like counter caches -- and it's not always immediately clear where that is optimal to place. In
this case, favor the creation of a new context that handles this interaction.

In Rails, it is considered bad form to invoke database calls from a view or template. In Phoenix we do not have this
restriction, and it is not necessary for a controller to do anything other than load the resource directly associated
with a route.

Unless there is a compelling reason for it to be placed elsewhere, business logic should be contained in `lib/philomena/`.
The web project is primarily concerned with presentation of the data and not the actual processing. Avoid importing
`Ecto.Query` outside of context modules.

These lists are intended as rules of thumb for didactic purposes. You should be able to use them for 90% of cases, and
break the rules when it makes sense to for clarity.

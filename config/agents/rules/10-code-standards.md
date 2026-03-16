<!-- Code-quality guardrail: ban type assertions (`as`) to force sound typing. -->

# Code Standards

> two things that make code actually maintainable:
>
> 1. reduce the layers a reader has to trace
> 2. reduce the state a reader has to hold in their head
>
> applies to every codebase. always.

- Never typecast. Never use `as`.

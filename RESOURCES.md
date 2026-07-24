---
purpose: Curate trusted sources for learning about agentic software factories.
applies_to: Lessons and questions governed by MISSION.md.
entrypoint: Read the annotated Knowledge sources relevant to the lesson.
verification: Every lesson claim links to a listed high-trust source.
update_when: A source is discredited, superseded, or a stated gap closes.
---

# Software Factory Resources

## Knowledge

- [Essay: “Why Software Factories Fail” — Dex Horthy](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/wsff.md)
  The course’s motivating argument: current agents optimize fast, testable outcomes while maintainability has delayed, hard-to-attribute costs. Use for: the complete thesis and proposed human-in-the-loop workflow.
- [Paper: “SWE-bench: Can Language Models Resolve Real-World GitHub Issues?” — Jimenez et al.](https://openreview.net/forum?id=VTF8yNQM66)
  Primary description of a benchmark that scores patches against repository issues and tests. Use for: understanding what common coding-agent evaluations do and do not measure.
- [Paper: “SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering” — Yang et al.](https://arxiv.org/abs/2405.15793)
  Primary evidence that tool-interface design materially changes agent performance. Use for: separating genuine harness gains from claims that harnesses solve software design.
- [Reference: “Shotgun Surgery” — Refactoring.Guru](https://refactoring.guru/smells/shotgun-surgery)
  Short explanation of the maintainability failure where one conceptual change requires edits across many locations. Use for: recognizing delayed architectural damage.

## Wisdom (Communities)

- [HumanLayer Discord](https://hlyr.dev/discord)
  Practitioner community centered on human-agent collaboration. Use for: testing workflow claims against teams operating real codebases.

## Gaps

- No fast, reliable, broadly accepted verifier for long-term maintainability
- Limited longitudinal evidence comparing lights-off and human-steered agent workflows

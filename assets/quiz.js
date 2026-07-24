document.querySelectorAll("[data-quiz]").forEach((quiz) => {
  const feedback = quiz.querySelector("[data-feedback]");

  quiz.querySelectorAll("button[data-answer]").forEach((button) => {
    button.addEventListener("click", () => {
      const correct = button.dataset.answer === "correct";

      quiz.querySelectorAll("button[data-answer]").forEach((candidate) => {
        candidate.classList.remove("correct", "incorrect");
      });

      button.classList.add(correct ? "correct" : "incorrect");
      feedback.textContent = correct
        ? button.dataset.feedback
        : `Not quite. ${button.dataset.feedback}`;
    });
  });
});

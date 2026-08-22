// Temporärer Nachweis für Ticket #6: Ein roter Test muss den PR-Check brechen.
// Dieser Commit wird nach dem Nachweis revertet.
import { expect, test } from "vitest";

test("CI red-test proof — intentionally failing", () => {
  expect(1).toBe(2);
});

// Fisher–Yates shuffle. Uniformly random — `array.sort(() => Math.random() - 0.5)`
// is statistically biased (the comparator isn't a real ordering, so V8 leans
// the output toward the original order). For question pools that bias means
// earlier rows in the DB show up disproportionately as "first question".
export function shuffle<T>(input: readonly T[]): T[] {
  const arr = input.slice()
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[arr[i], arr[j]] = [arr[j], arr[i]]
  }
  return arr
}

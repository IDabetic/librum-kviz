import { redirect } from 'next/navigation'

// Brzi kviz uses the same `questions` pool as PRO and Trivia duel.
// "Brzi kviz" stays in the sidebar so admins can find it, but the link
// just sends them to the shared pool admin where they actually edit
// the questions.
export default function BrziKvizAdminRedirect() {
  redirect('/majmun/pitanja')
}

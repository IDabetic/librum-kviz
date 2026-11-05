export type Profile = {
  id: string
  email: string | null
  phone: string | null
  first_name: string
  last_name: string
  created_at: string
  suspended_until?: string | null
  is_blocked?: boolean
}

export type Quiz = {
  id: string
  title: string
  description: string | null
  category: string | null
  difficulty: 'lako' | 'srednje' | 'tesko'
  cover_color: string
  plays: number
  created_at: string
  question_count?: number
}

export type Question = {
  id: string
  quiz_id: string
  question_text: string
  options: string[]
  correct_answer: number
  explanation: string | null
  order_num: number
}

export type QuizResult = {
  id: string
  user_id: string
  quiz_id: string
  score: number
  total: number
  time_taken: number | null
  completed_at: string
  profiles?: { first_name: string; last_name: string }
  quizzes?: { title: string }
}

export type GameRoom = {
  id: string
  room_code: string
  quiz_id: string
  host_id: string
  guest_id: string | null
  status: 'waiting' | 'playing' | 'finished'
  question_ids: string[]
  host_answers: (number | null)[]
  guest_answers: (number | null)[]
  host_score: number
  guest_score: number
  host_finished: boolean
  guest_finished: boolean
  total_questions: number
  created_at: string
}

export type QuestionSubmission = {
  id: string
  question_text: string
  correct_answer: string
  // Tri netačna odgovora kad je predlog stigao sa /dodaj-pitanja; prazan
  // niz za starije predloge sa /predlozi-pitanje, gde ih urednik dopisuje.
  wrong_answers: string[]
  // U koji fond pitanja predlog ide: 'pro' | 'book' | 'kafana'.
  segment: string
  genre: string | null
  // 'form' (obrazac), 'xml' ili 'xlsx' (grupni uvoz).
  source: string
  // 'pending' | 'accepted' | 'rejected'. Predlozi se ne brišu pri obradi
  // nego menjaju status, da korisnik vidi šta je bilo sa njegovim pitanjem.
  status: string
  reject_reason: string | null
  reviewed_at: string | null
  reviewed_by: string | null
  submitted_by: string | null
  submitter_email: string | null
  created_at: string
}

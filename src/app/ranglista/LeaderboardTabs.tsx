'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import type { SurvivorRow, DuelRow, HangmanRow, QuickRow, BookRow, KafanaRow, AllPeriods } from './page'
import { IconHome, IconSwords, IconHint, IconTime, IconDiscover, IconStar } from '@/components/icons'

const MEDALS = ['🥇', '🥈', '🥉']
const PERIODS = [
  { id: 'today', label: 'Danas' },
  { id: 'week',  label: 'Nedelja' },
  { id: 'month', label: 'Mesec' },
  { id: 'all',   label: 'Sve vreme' },
] as const
type PeriodId = typeof PERIODS[number]['id']

// Top-N options. `null` = no cap. Default is Top 10 — the focused
// view; visitors who want more switch up.
const TOP_OPTIONS: { id: 'top10' | 'top50' | 'top100' | 'all'; label: string; n: number | null }[] = [
  { id: 'top10',  label: 'Top 10',  n: 10 },
  { id: 'top50',  label: 'Top 50',  n: 50 },
  { id: 'top100', label: 'Top 100', n: 100 },
  { id: 'all',    label: 'Svi',     n: null },
]
type TopId = typeof TOP_OPTIONS[number]['id']
const DEFAULT_TOP: TopId = 'top10'

// Inner list is bounded so the page itself doesn't grow to 200 rows tall.
// Tuned to roughly 8 rows visible at once; the rest scrolls inside the card.
const LIST_MAX_HEIGHT = 'max-h-[520px] overflow-y-auto'

const GAMES = [
  { id: 'survivor', label: 'PRO kviz',       Icon: IconHome,     accent: '#12907E' },
  { id: 'book',     label: 'Book kviz',      Icon: IconDiscover, accent: '#8A6A12' },
  { id: 'kafana',   label: 'Kafanski kviz',  Icon: IconStar,     accent: '#C42B4F' },
  { id: 'duel',     label: 'Trivia duel',    Icon: IconSwords,   accent: '#FFD84D' },
  { id: 'hangman',  label: 'Vešanje',        Icon: IconHint,     accent: '#12907E' },
  { id: 'quick',    label: 'Brzi kviz',      Icon: IconTime,     accent: '#E5385C' },
] as const
type GameId = typeof GAMES[number]['id']

export default function LeaderboardTabs({
  survivor, duel, hangman, quick, book, kafana, user,
}: {
  survivor: AllPeriods<SurvivorRow>
  duel: AllPeriods<DuelRow>
  hangman: AllPeriods<HangmanRow>
  quick: AllPeriods<QuickRow>
  book: AllPeriods<BookRow>
  kafana: AllPeriods<KafanaRow>
  user: boolean
}) {
  const [game, setGame] = useState<GameId>('survivor')
  const [period, setPeriod] = useState<PeriodId>('today')
  const [topId, setTopId] = useState<TopId>(DEFAULT_TOP)
  const top = TOP_OPTIONS.find(t => t.id === topId) ?? TOP_OPTIONS[0]
  const limit = top.n

  return (
    <>
      {/* Game mode pills */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 mb-3">
        {GAMES.map(g => {
          const active = game === g.id
          return (
            <button key={g.id} onClick={() => setGame(g.id)}
              aria-pressed={active}
              className="flex items-center justify-center gap-2 py-3 rounded-2xl text-[13px] font-bold transition-all"
              style={active
                ? { background: '#151515', color: '#FFFFFF', border: '2px solid #151515', boxShadow: '0 4px 0 rgba(21,21,21,0.3)' }
                : { background: '#FFFFFF', color: '#151515', border: '1.5px solid #E7E1D0' }
              }>
              <g.Icon size={14} strokeWidth={2.2} />
              {g.label}
            </button>
          )
        })}
      </div>

      {/* Period i broj redova: podvučen izbor, ne kapsule. */}
      <div className="flex flex-wrap items-end justify-between gap-x-8 gap-y-2 mb-6">
        <div className="izbor overflow-x-auto" role="tablist" aria-label="Period">
          {PERIODS.map(p => (
            <button key={p.id} role="tab" aria-selected={period === p.id} onClick={() => setPeriod(p.id)}
              className="text-[14px] whitespace-nowrap">
              {p.label}
            </button>
          ))}
        </div>
        <div className="izbor overflow-x-auto" role="tablist" aria-label="Broj igrača">
          {TOP_OPTIONS.map(t => (
            <button key={t.id} role="tab" aria-selected={topId === t.id} onClick={() => setTopId(t.id)}
              className="text-[14px] whitespace-nowrap">
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {game === 'survivor' && <SurvivorBoard data={survivor[period]} period={period} user={user} limit={limit} />}
      {game === 'book'     && <BookBoard     data={book[period]}     period={period} user={user} limit={limit} />}
      {game === 'kafana'   && <KafanaBoard   data={kafana[period]}   period={period} user={user} limit={limit} />}
      {game === 'duel'     && <DuelBoard     data={duel[period]}     period={period} user={user} limit={limit} />}
      {game === 'hangman'  && <HangmanBoard  data={hangman[period]}  period={period} user={user} limit={limit} />}
      {game === 'quick'    && <QuickBoard    data={quick[period]}    period={period} user={user} limit={limit} />}
    </>
  )
}

// ── Shared helpers ──────────────────────────────────────────────────────
function Avatar({ name, avatar, size = 40, accent = '#12907E' }: { name: string; avatar: string | null; size?: number; accent?: string }) {
  return (
    <div className="rounded-2xl overflow-hidden flex-shrink-0 bg-[#E7E1D0]" style={{ width: size, height: size }}>
      {avatar
        ? <Image src={`/avatars/${avatar}`} alt={name} width={size} height={size} className="w-full h-full object-cover" />
        : <div className="w-full h-full flex items-center justify-center font-bold text-white" style={{ background: accent, fontSize: size * 0.4 }}>{name[0]}</div>}
    </div>
  )
}

function Rank({ i }: { i: number }) {
  return (
    <span className="w-9 text-center flex-shrink-0">
      {i < 3
        ? <span className="text-[26px] sm:text-[28px] leading-none">{MEDALS[i]}</span>
        : <span className="text-[14px] font-black" style={{ color: '#6F6C66' }}>{i + 1}</span>}
    </span>
  )
}

// Soft tinted background for top-3 rows so the podium reads at a
// glance even before the medal glyph registers.
const TOP_TINTS: Record<number, string> = {
  0: 'linear-gradient(90deg, #FFF6D6 0%, transparent 60%)',
  1: 'linear-gradient(90deg, #ECEEF1 0%, transparent 60%)',
  2: 'linear-gradient(90deg, #FCE7DD 0%, transparent 60%)',
}
function rowStyle(i: number): React.CSSProperties {
  return i < 3 ? { background: TOP_TINTS[i] } : {}
}

function EmptyBoard({ user, href, label, icon }: { user: boolean; href: string; label: string; icon: string }) {
  return (
    <div className="card-soft py-16 text-center px-6">
      <div className="text-5xl mb-4">{icon}</div>
      <p className="font-bold text-[16px] mb-1" style={{ color: '#151515' }}>Nema rezultata u ovom periodu</p>
      <p className="text-[13px] mb-6" style={{ color: '#6F6C66' }}>Probaj drugi period ili budi prvi koji će igrati.</p>
      <Link href={user ? href : '/auth/registracija'} className="btn btn-primary btn-md">
        {user ? label : 'Registruj se'}
      </Link>
    </div>
  )
}

function PeriodHint({ period }: { period: PeriodId }) {
  const map: Record<PeriodId, string> = {
    today: 'Najbolji rezultati danas',
    week: 'Najbolji rezultati u poslednjih 7 dana',
    month: 'Najbolji rezultati u poslednjih 30 dana',
    all: 'Najbolji rezultati svih vremena',
  }
  return (
    <p className="text-center text-[12px] mb-3" style={{ color: '#6F6C66' }}>{map[period]}</p>
  )
}

// ── SURVIVOR ────────────────────────────────────────────────────────────
function SurvivorBoard({ data, period, user, limit }: { data: SurvivorRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/pro-kviz" label="Igraj PRO kviz" icon="🎯" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#12907E" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                {p.questionsReached} pit. · {Math.round(p.accuracy)}% · niz {p.bestCombo}
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#151515' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── DUEL ────────────────────────────────────────────────────────────────
function DuelBoard({ data, period, user, limit }: { data: DuelRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/igraj-zajedno" label="Igraj duel" icon="⚔️" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#FFD84D" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>{p.plays} {p.plays === 1 ? 'duel' : 'duela'}</p>
            </div>
            <div className="flex gap-2.5 text-center flex-shrink-0">
              <div><div className="font-bold text-[15px]" style={{ color: '#12907E' }}>{p.wins}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>W</div></div>
              <div><div className="font-bold text-[15px]" style={{ color: '#6F6C66' }}>{p.draws}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>D</div></div>
              <div><div className="font-bold text-[15px]" style={{ color: '#E5385C' }}>{p.losses}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#6F6C66' }}>L</div></div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── HANGMAN ─────────────────────────────────────────────────────────────
function HangmanBoard({ data, period, user, limit }: { data: HangmanRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/vesanje" label="Igraj Vešanje" icon="🎯" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#12907E" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>{p.total} {p.total === 1 ? 'igra' : 'igara'} · {p.winRate}%</p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#12907E' }}>{p.wins}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>{p.wins === 1 ? 'pobeda' : 'pobeda'}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── BRZI KVIZ ───────────────────────────────────────────────────────────
function QuickBoard({ data, period, user, limit }: { data: QuickRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/brzi-kviz" label="Igraj Brzi kviz" icon="⚡" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#E5385C" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>{p.correct} tačno · {Math.round(p.accuracy)}%</p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#151515' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── BOOK KVIZ ───────────────────────────────────────────────────────────
function BookBoard({ data, period, user, limit }: { data: BookRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/book-kviz" label="Igraj Book kviz" icon="📚" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#8A6A12" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
                {p.topGenre && (
                  <span className="chip" style={{ background: '#FFF3C4', color: '#8A6A12' }}>
                    {p.topGenre}
                  </span>
                )}
              </div>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                {p.questionsReached} pit. · {Math.round(p.accuracy)}% tačnih
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#151515' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── KAFANSKI KVIZ ───────────────────────────────────────────────────────
function KafanaBoard({ data, period, user, limit }: { data: KafanaRow[]; period: PeriodId; user: boolean; limit: number | null }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/kafanski-kviz" label="Igraj Kafanski kviz" icon="🎵" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className={`divide-y ${LIST_MAX_HEIGHT}`} style={{ borderColor: '#E7E1D0' }}>
        {data.slice(0, limit ?? data.length).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#E7E1D0] transition-colors" style={rowStyle(i)}>
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#C42B4F" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#151515' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#6F6C66' }}>
                {p.questionsReached} pit. · {Math.round(p.accuracy)}% · niz {p.bestCombo}
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#C42B4F' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#6F6C66' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

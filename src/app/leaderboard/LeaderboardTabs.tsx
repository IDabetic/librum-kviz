'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import type { SurvivorRow, DuelRow, HangmanRow, QuickRow, BookRow, AllPeriods } from './page'
import { IconHome, IconSwords, IconHint, IconTime, IconDiscover } from '@/components/icons'

const MEDALS = ['🥇', '🥈', '🥉']
const PERIODS = [
  { id: 'today', label: 'Danas' },
  { id: 'week',  label: 'Nedelja' },
  { id: 'month', label: 'Mesec' },
  { id: 'all',   label: 'Sve vreme' },
] as const
type PeriodId = typeof PERIODS[number]['id']

const GAMES = [
  { id: 'survivor', label: 'PRO kviz',    Icon: IconHome,     accent: '#609DED' },
  { id: 'book',     label: 'Book kviz',   Icon: IconDiscover, accent: '#9c7a13' },
  { id: 'duel',     label: 'Trivia duel', Icon: IconSwords,   accent: '#FFCB46' },
  { id: 'hangman',  label: 'Vešanje',     Icon: IconHint,     accent: '#4CAF50' },
  { id: 'quick',    label: 'Brzi kviz',   Icon: IconTime,     accent: '#E55353' },
] as const
type GameId = typeof GAMES[number]['id']

export default function LeaderboardTabs({
  survivor, duel, hangman, quick, book, user,
}: {
  survivor: AllPeriods<SurvivorRow>
  duel: AllPeriods<DuelRow>
  hangman: AllPeriods<HangmanRow>
  quick: AllPeriods<QuickRow>
  book: AllPeriods<BookRow>
  user: boolean
}) {
  const [game, setGame] = useState<GameId>('survivor')
  const [period, setPeriod] = useState<PeriodId>('today')

  return (
    <>
      {/* Game mode pills */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-2 mb-3">
        {GAMES.map(g => {
          const active = game === g.id
          return (
            <button key={g.id} onClick={() => setGame(g.id)}
              className="flex items-center justify-center gap-2 py-3 rounded-2xl text-[13px] font-bold transition-all"
              style={active
                ? { background: g.accent, color: g.id === 'duel' ? '#343434' : 'white' }
                : { background: '#F2F2F2', color: '#9C9C9C' }
              }>
              <g.Icon size={14} strokeWidth={2.2} />
              {g.label}
            </button>
          )
        })}
      </div>

      {/* Period pills */}
      <div className="flex p-1 rounded-full mb-6 max-w-md mx-auto overflow-x-auto" style={{ background: '#F2F2F2' }}>
        {PERIODS.map(p => (
          <button key={p.id} onClick={() => setPeriod(p.id)}
            className="flex-1 py-2 px-3 rounded-full text-[12px] font-semibold transition-all whitespace-nowrap"
            style={period === p.id
              ? { background: '#FCFCFC', color: '#343434', boxShadow: '0 2px 8px rgba(52,52,52,0.06)' }
              : { color: '#9C9C9C' }}>
            {p.label}
          </button>
        ))}
      </div>

      {game === 'survivor' && <SurvivorBoard data={survivor[period]} period={period} user={user} />}
      {game === 'book'     && <BookBoard     data={book[period]}     period={period} user={user} />}
      {game === 'duel'     && <DuelBoard     data={duel[period]}     period={period} user={user} />}
      {game === 'hangman'  && <HangmanBoard  data={hangman[period]}  period={period} user={user} />}
      {game === 'quick'    && <QuickBoard    data={quick[period]}    period={period} user={user} />}
    </>
  )
}

// ── Shared helpers ──────────────────────────────────────────────────────
function Avatar({ name, avatar, size = 40, accent = '#609DED' }: { name: string; avatar: string | null; size?: number; accent?: string }) {
  return (
    <div className="rounded-2xl overflow-hidden flex-shrink-0 bg-[#F2F2F2]" style={{ width: size, height: size }}>
      {avatar
        ? <Image src={`/avatars/${avatar}`} alt={name} width={size} height={size} className="w-full h-full object-cover" />
        : <div className="w-full h-full flex items-center justify-center font-bold text-white" style={{ background: accent, fontSize: size * 0.4 }}>{name[0]}</div>}
    </div>
  )
}

function Rank({ i }: { i: number }) {
  return (
    <span className="w-7 text-center flex-shrink-0">
      {i < 3 ? <span className="text-lg">{MEDALS[i]}</span> : <span className="text-[13px] font-bold" style={{ color: '#9C9C9C' }}>{i + 1}</span>}
    </span>
  )
}

function EmptyBoard({ user, href, label, icon }: { user: boolean; href: string; label: string; icon: string }) {
  return (
    <div className="card-soft py-16 text-center px-6">
      <div className="text-5xl mb-4">{icon}</div>
      <p className="font-bold text-[16px] mb-1" style={{ color: '#343434' }}>Nema rezultata u ovom periodu</p>
      <p className="text-[13px] mb-6" style={{ color: '#9C9C9C' }}>Probaj drugi period ili budi prvi koji će igrati.</p>
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
    <p className="text-center text-[12px] mb-3" style={{ color: '#9C9C9C' }}>{map[period]}</p>
  )
}

// ── SURVIVOR ────────────────────────────────────────────────────────────
function SurvivorBoard({ data, period, user }: { data: SurvivorRow[]; period: PeriodId; user: boolean }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/igraj" label="Igraj PRO kviz" icon="🎯" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {data.slice(0, 50).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#F2F2F2] transition-colors">
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#609DED" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                {p.questionsReached} pit. · {Math.round(p.accuracy)}% · niz {p.bestCombo}
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#9C9C9C' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── DUEL ────────────────────────────────────────────────────────────────
function DuelBoard({ data, period, user }: { data: DuelRow[]; period: PeriodId; user: boolean }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/igraj-zajedno" label="Igraj duel" icon="⚔️" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {data.slice(0, 50).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#F2F2F2] transition-colors">
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#FFCB46" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{p.plays} {p.plays === 1 ? 'duel' : 'duela'}</p>
            </div>
            <div className="flex gap-2.5 text-center flex-shrink-0">
              <div><div className="font-bold text-[15px]" style={{ color: '#4CAF50' }}>{p.wins}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>W</div></div>
              <div><div className="font-bold text-[15px]" style={{ color: '#9C9C9C' }}>{p.draws}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>D</div></div>
              <div><div className="font-bold text-[15px]" style={{ color: '#E55353' }}>{p.losses}</div><div className="text-[10px] font-bold uppercase tracking-wider" style={{ color: '#9C9C9C' }}>L</div></div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── HANGMAN ─────────────────────────────────────────────────────────────
function HangmanBoard({ data, period, user }: { data: HangmanRow[]; period: PeriodId; user: boolean }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/vesanje" label="Igraj Vešanje" icon="🎯" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {data.slice(0, 50).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#F2F2F2] transition-colors">
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#4CAF50" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{p.total} {p.total === 1 ? 'igra' : 'igara'} · {p.winRate}%</p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#4CAF50' }}>{p.wins}</div>
              <div className="text-[11px]" style={{ color: '#9C9C9C' }}>{p.wins === 1 ? 'pobeda' : 'pobeda'}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── BRZI KVIZ ───────────────────────────────────────────────────────────
function QuickBoard({ data, period, user }: { data: QuickRow[]; period: PeriodId; user: boolean }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/brzi-kviz" label="Igraj Brzi kviz" icon="⚡" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {data.slice(0, 50).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#F2F2F2] transition-colors">
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#E55353" />
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>{p.correct} tačno · {Math.round(p.accuracy)}%</p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#9C9C9C' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

// ── BOOK KVIZ ───────────────────────────────────────────────────────────
function BookBoard({ data, period, user }: { data: BookRow[]; period: PeriodId; user: boolean }) {
  if (data.length === 0) return <EmptyBoard user={user} href="/book-kviz" label="Igraj Book kviz" icon="📚" />
  return (
    <div className="card-soft overflow-hidden">
      <PeriodHint period={period} />
      <div className="divide-y" style={{ borderColor: '#F2F2F2' }}>
        {data.slice(0, 50).map((p, i) => (
          <Link key={i} href={`/profil/${p.userId}`} className="flex items-center gap-3 px-5 py-3.5 hover:bg-[#F2F2F2] transition-colors">
            <Rank i={i} />
            <Avatar name={p.name} avatar={p.avatar} accent="#9c7a13" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <p className="font-semibold text-[14px] truncate tracking-tight" style={{ color: '#343434' }}>{p.name}</p>
                {p.topGenre && (
                  <span className="chip" style={{ background: '#FFECBC', color: '#9c7a13' }}>
                    {p.topGenre}
                  </span>
                )}
              </div>
              <p className="text-[12px]" style={{ color: '#9C9C9C' }}>
                {p.questionsReached} pit. · {Math.round(p.accuracy)}% tačnih
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className="font-black text-[18px] tracking-tight" style={{ color: '#343434' }}>{p.score}</div>
              <div className="text-[11px]" style={{ color: '#9C9C9C' }}>bodova</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

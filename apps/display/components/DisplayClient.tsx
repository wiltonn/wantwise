"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  agoText,
  countdownUntil,
  formatPrice,
  phaseOf,
  statusText,
  thinkingAbout,
  waitProgress,
  type DisplaySnapshot,
  type DisplayWant,
} from "@/lib/domain";
import styles from "./display.module.css";

const FEATURE_MS = 20_000; // how long each Want is featured
const POLL_MS = 60_000; // data refresh
const TICK_MS = 15_000; // clock / countdown refresh
const RELOAD_MS = 6 * 3_600_000; // full reload guards against slow leaks on always-on screens
const DRIFT_MS = 10 * 60_000; // OLED burn-in protection
const RAIL_SIZE = 6;
const STALE_MS = 3 * 3_600_000;

export default function DisplayClient({ initial, initialFeatured = 0 }: { initial: DisplaySnapshot; initialFeatured?: number }) {
  const [snapshot, setSnapshot] = useState(initial);
  const [lastSuccess, setLastSuccess] = useState(() => new Date(initial.generatedAt));
  // Starts at the server's time so the first client render matches the server HTML exactly.
  const [now, setNow] = useState(() => new Date(initial.generatedAt));
  const [featured, setFeatured] = useState(initialFeatured);
  const [drift, setDrift] = useState({ x: 0, y: 0 });
  const [controlsVisible, setControlsVisible] = useState(false);
  const idleTimer = useRef<number | undefined>(undefined);

  const tz = snapshot.timeZone;
  const items = useMemo(() => thinkingAbout(snapshot.wants, now), [snapshot.wants, now]);
  const featuredIndex = items.length ? featured % items.length : 0;
  const current = items[featuredIndex];

  // Stage scaling to the window (the initial value is set before paint by an inline script).
  useEffect(() => {
    const fit = () =>
      document.documentElement.style.setProperty(
        "--stage-scale",
        String(Math.min(window.innerWidth / 1920, window.innerHeight / 1080)),
      );
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, []);

  // Clock + countdowns.
  useEffect(() => {
    setNow(new Date());
    const id = window.setInterval(() => setNow(new Date()), TICK_MS);
    return () => window.clearInterval(id);
  }, []);

  // Slow rotation of the featured Want.
  useEffect(() => {
    if (items.length < 2) return;
    const id = window.setTimeout(() => setFeatured((i) => i + 1), FEATURE_MS);
    return () => window.clearTimeout(id);
  }, [featured, items.length]);

  // Poll for new data. Failures keep the last good snapshot on screen.
  useEffect(() => {
    const id = window.setInterval(async () => {
      try {
        const res = await fetch("/api/snapshot", { cache: "no-store" });
        if (!res.ok) return;
        setSnapshot(await res.json());
        setLastSuccess(new Date());
      } catch {
        /* offline: keep showing what we have */
      }
    }, POLL_MS);
    return () => window.clearInterval(id);
  }, []);

  // Long-running screen care: periodic reload, burn-in drift, wake lock.
  useEffect(() => {
    const reload = window.setTimeout(() => window.location.reload(), RELOAD_MS);
    const driftId = window.setInterval(
      () => setDrift({ x: Math.round(Math.random() * 12 - 6), y: Math.round(Math.random() * 8 - 4) }),
      DRIFT_MS,
    );

    let lock: WakeLockSentinel | null = null;
    const requestLock = async () => {
      try {
        if (document.visibilityState === "visible" && "wakeLock" in navigator) {
          lock = await navigator.wakeLock.request("screen");
        }
      } catch {
        /* not supported or refused; OS power settings apply */
      }
    };
    requestLock();
    document.addEventListener("visibilitychange", requestLock);

    return () => {
      window.clearTimeout(reload);
      window.clearInterval(driftId);
      document.removeEventListener("visibilitychange", requestLock);
      lock?.release().catch(() => {});
    };
  }, []);

  const toggleFullscreen = useCallback(() => {
    if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
    else document.documentElement.requestFullscreen().catch(() => {});
  }, []);

  // Controls and cursor appear on mouse movement and hide again after 3 s.
  useEffect(() => {
    const wake = () => {
      setControlsVisible(true);
      window.clearTimeout(idleTimer.current);
      idleTimer.current = window.setTimeout(() => setControlsVisible(false), 3000);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "f" || e.key === "F") toggleFullscreen();
      if (e.key === "ArrowRight") setFeatured((i) => i + 1);
      if (e.key === "ArrowLeft") setFeatured((i) => i - 1 + items.length);
      wake();
    };
    window.addEventListener("mousemove", wake);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("mousemove", wake);
      window.removeEventListener("keydown", onKey);
    };
  }, [toggleFullscreen, items.length]);

  // A sliding window that always holds the featured Want, with one card of context before it.
  const railStart = Math.max(0, Math.min(featuredIndex - 1, items.length - RAIL_SIZE));
  const rail = items.slice(railStart, railStart + RAIL_SIZE);
  const isStale = now.getTime() - lastSuccess.getTime() > STALE_MS;

  return (
    <main className={styles.viewport} data-controls={controlsVisible}>
      {/* Ambient backdrop: the featured image, heavily blurred. */}
      <div className={styles.backdrop} aria-hidden>
        {items.map((w, i) =>
          w.imageUrl ? (
            <div
              key={w.id}
              className={styles.backdropLayer}
              data-active={i === featuredIndex}
              style={{ backgroundImage: `url(${w.imageUrl})` }}
            />
          ) : null,
        )}
        <div className={styles.backdropShade} />
      </div>

      <div className={styles.stage} style={{ translate: `${drift.x}px ${drift.y}px` }}>
        <header className={styles.header}>
          <div className={styles.brand}>
            <span className={styles.wordmark}>WantWise</span>
            <span className={styles.headerRule} />
            <span className={styles.scene}>
              {snapshot.child.displayName} is thinking about
              {items.length > 0 && <span className={styles.count}>{items.length}</span>}
            </span>
          </div>
          <Clock now={now} timeZone={tz} />
        </header>

        {current ? (
          <>
            <section className={styles.hero} aria-live="polite">
              {items.map((w, i) => (
                <HeroItem key={w.id} want={w} active={i === featuredIndex} now={now} timeZone={tz} />
              ))}
            </section>

            <section className={styles.rail} aria-label="All Wants">
              {rail.map((w) => (
                <RailCard
                  key={w.id}
                  want={w}
                  active={w.id === current.id}
                  rotateKey={featured}
                  now={now}
                  timeZone={tz}
                  onSelect={() => setFeatured(items.indexOf(w))}
                />
              ))}
            </section>
          </>
        ) : (
          <section className={styles.empty}>
            <p className={styles.emptyTitle}>Nothing on the list right now.</p>
            <p className={styles.emptySub}>New Wants will appear here when they’re added.</p>
          </section>
        )}

        {isStale && (
          <p className={styles.stale}>Last updated {formatTime(lastSuccess, tz)}</p>
        )}
      </div>

      <button className={styles.fullscreen} onClick={toggleFullscreen} type="button">
        Full screen <kbd>F</kbd>
      </button>
    </main>
  );
}

function HeroItem({ want, active, now, timeZone }: { want: DisplayWant; active: boolean; now: Date; timeZone: string }) {
  const phase = phaseOf(want, now);
  const price = formatPrice(want.priceMinor, want.currency);
  const progress = waitProgress(want, now);
  const revisit = want.revisitAt ? new Date(want.revisitAt) : null;

  return (
    <article className={styles.heroItem} data-active={active} aria-hidden={!active}>
      <div className={styles.heroMedia}>
        {want.imageUrl ? (
          <>
            <div className={styles.heroMediaFill} style={{ backgroundImage: `url(${want.imageUrl})` }} />
            <img className={styles.heroImg} src={want.imageUrl} alt="" />
          </>
        ) : (
          <div className={styles.heroPlaceholder}>{initials(want.title)}</div>
        )}
      </div>

      <div className={styles.heroText}>
        <StatusChip want={want} now={now} timeZone={timeZone} large />
        <h1 className={styles.heroTitle}>{want.title}</h1>
        {price && <p className={styles.heroPrice}>{price}</p>}
        {want.reason && (
          <div className={styles.heroWhy}>
            <span className={styles.label}>Why</span>
            <p className={styles.heroReason}>{want.reason}</p>
          </div>
        )}

        <div className={styles.heroFooter}>
          {progress != null && (
            <div className={styles.progressTrack} data-phase={phase}>
              <div className={styles.progressFill} style={{ width: `${Math.max(progress, 0.02) * 100}%` }} />
            </div>
          )}
          <div className={styles.heroDates}>
            <span>Added {agoText(new Date(want.createdAt), now, timeZone)}</span>
            {revisit && phase === "waiting" && <span>Think again {formatRevisit(revisit, now, timeZone)}</span>}
            {phase === "readyToReconsider" && <span>Time to take another look</span>}
            {phase === "needsReflection" && <span>Waiting time not chosen yet</span>}
          </div>
        </div>
      </div>
    </article>
  );
}

function RailCard(props: {
  want: DisplayWant;
  active: boolean;
  rotateKey: number;
  now: Date;
  timeZone: string;
  onSelect: () => void;
}) {
  const { want, active, rotateKey, now, timeZone, onSelect } = props;
  const phase = phaseOf(want, now);
  return (
    <button type="button" className={styles.card} data-active={active} data-phase={phase} onClick={onSelect}>
      <div className={styles.cardMedia} data-source={want.sourceType}>
        {want.imageUrl ? (
          <img src={want.imageUrl} alt="" />
        ) : (
          <div className={styles.cardPlaceholder}>{initials(want.title)}</div>
        )}
      </div>
      <div className={styles.cardText}>
        <p className={styles.cardTitle}>{want.title}</p>
        <p className={styles.cardStatus}>{statusText(want, now, timeZone)}</p>
      </div>
      {active && <span key={rotateKey} className={styles.cardTimer} style={{ animationDuration: `${FEATURE_MS}ms` }} />}
    </button>
  );
}

function StatusChip({ want, now, timeZone, large }: { want: DisplayWant; now: Date; timeZone: string; large?: boolean }) {
  const phase = phaseOf(want, now);
  let tone: "ready" | "soon" | "calm" = "calm";
  if (phase === "readyToReconsider") tone = "ready";
  else if (phase === "waiting" && want.revisitAt) {
    const kind = countdownUntil(new Date(want.revisitAt), now, timeZone).kind;
    if (kind === "today" || kind === "tomorrow") tone = "soon";
  }
  return (
    <span className={styles.chip} data-tone={tone} data-large={large}>
      <span className={styles.chipDot} />
      {statusText(want, now, timeZone)}
    </span>
  );
}

function Clock({ now, timeZone }: { now: Date; timeZone: string }) {
  return (
    <div className={styles.clock}>
      <span className={styles.clockTime}>{formatTime(now, timeZone)}</span>
      <span className={styles.clockDate}>
        {new Intl.DateTimeFormat("en-CA", { timeZone, weekday: "long", month: "long", day: "numeric" }).format(now)}
      </span>
    </div>
  );
}

function formatTime(d: Date, timeZone: string) {
  return new Intl.DateTimeFormat("en-CA", { timeZone, hour: "numeric", minute: "2-digit" }).format(d);
}

function formatRevisit(revisit: Date, now: Date, timeZone: string) {
  const kind = countdownUntil(revisit, now, timeZone).kind;
  if (kind === "today") return `today, ${formatTime(revisit, timeZone)}`;
  if (kind === "tomorrow") return "tomorrow";
  return new Intl.DateTimeFormat("en-CA", { timeZone, weekday: "long", month: "short", day: "numeric" }).format(revisit);
}

function initials(title: string) {
  return title
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("");
}

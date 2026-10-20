import { useRef, useState } from 'react';
import { ArrowDown, ArrowLeft, ArrowRight, BookOpen, Bookmark, Check, ChevronRight, Languages, MessageCircle, Moon, Share2, Sparkles, Sun, Target, Trophy, Bell } from 'lucide-react';
import type { AppScreenshot } from './screenshots';
import { screenshot, screenshots } from './screenshots';
import { milestones } from './releases';
import './public.css';
function Brand() {
  return <span className="aq-brand">
    <img src="/showcase/brand/logo.webp" width="44" height="44" alt="" />
    <span>AptiQu</span>
  </span>;
}
function Phone({
  entry,
  priority = false,
  className = ''
}: {
  entry: AppScreenshot;
  priority?: boolean;
  className?: string;
}) {
  const [failed, setFailed] = useState(false);
  return <div className={`aq-phone ${className}`}>
    {entry.available && !failed ? <img src={entry.path} alt={entry.alt} width="390" height="844" loading={priority ? 'eager' : 'lazy'} onError={() => setFailed(true)} /> : <div className="aq-image-fallback">
      <BookOpen size={32} />
      <strong>{entry.title}</strong>
      <span>App preview unavailable</span>
    </div>}
  </div>;
}
function ScreenshotGallery() {
  const track = useRef<HTMLDivElement>(null);
  const entries = screenshots.filter(entry => entry.available && entry.theme === 'dark').sort((a, b) => a.order - b.order);
  const move = (direction: number) => {
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    track.current?.scrollBy({
      left: direction * 300,
      behavior: reduceMotion ? 'instant' : 'smooth'
    });
  };
  return <section id="preview" className="aq-section aq-preview">
    <div className="aq-section-heading">
      <div>
        <p className="aq-eyebrow">A closer look</p>
        <h2>Meet your next<br />learning habit.</h2>
      </div>
      <div className="aq-gallery-intro">
        <p>The actual AptiQu interface.<br />Made for the way you learn and play.</p>
        <div className="aq-gallery-controls">
          <button onClick={() => move(-1)} aria-label="Scroll to previous app previews">
            <ArrowLeft size={20} />
          </button>
          <button onClick={() => move(1)} aria-label="Scroll to next app previews">
            <ArrowRight size={20} />
          </button>
        </div>
      </div>
    </div>
    <div className="aq-gallery" ref={track} tabIndex={0} role="region" aria-label="App screenshots. Scroll horizontally to explore.">{entries.map((entry, index) => <figure key={entry.id}>
        <div className="aq-gallery-label">
          <span>0{index + 1}</span>
          <strong>{entry.title}</strong>
        </div>
        <Phone entry={entry} />
        <figcaption>{entry.caption}</figcaption>
      </figure>)}</div>
    <p className="aq-preview-note">Real Flutter UI, rendered with demo data. Swipe or scroll to explore.</p>
  </section>;
}
function ThemePreview() {
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');
  return <section className="aq-theme aq-section" aria-labelledby="theme-title">
    <div className="aq-theme-art">
      <div className="aq-theme-split" aria-hidden="true" />
      <Phone key={theme} entry={screenshot(theme === 'dark' ? 'home' : 'home-light')} />
    </div>
    <div>
      <p className="aq-eyebrow">Easy on the eyes</p>
      <h2 id="theme-title">Your focus.<br />Your atmosphere.</h2>
      <p>Early starts or late-night practice. Choose Light, Dark, or let AptiQu follow your device.</p>
      <div className="aq-theme-control" role="group" aria-label="Preview the app appearance">
        <button aria-pressed={theme === 'dark'} onClick={() => setTheme('dark')}>
          <Moon size={17} />Dark</button>
        <button aria-pressed={theme === 'light'} onClick={() => setTheme('light')}>
          <Sun size={18} />Light</button>
      </div>
      <span className="aq-small">Switch the preview. Find your favourite.</span>
    </div>
  </section>;
}
const upcoming = [{
  icon: MessageCircle,
  title: 'A little help, right in the lesson.',
  label: 'Lesson AI',
  text: 'Ask for a clearer explanation, another example or another language—without losing your place.'
}, {
  icon: Bookmark,
  title: 'Keep the good questions.',
  label: 'Bookmarks',
  text: 'Save useful questions from Practice or PvP. Come back when you want another try.'
}, {
  icon: Share2,
  title: 'One question. Sixty seconds.',
  label: 'Shareable challenges',
  text: 'Send someone a question through a link and challenge them to beat the clock.'
}, {
  icon: Bell,
  title: 'A useful nudge.',
  label: 'Push notifications',
  text: 'Helpful mobile reminders for Daily Challenges and your learning routine.'
}, {
  icon: Target,
  title: 'Know where to go next.',
  label: 'AI performance feedback',
  text: 'Private feedback after Practice and Ranked: what went well and which patterns need work.'
}, {
  icon: Trophy,
  title: 'More moments worth earning.',
  label: 'Expanded achievements',
  text: 'More milestones and collectible badges for learning, practice, competition and consistency.'
}];
function ReleaseTimeline() {
  return <section id="updates" className="aq-section aq-updates">
    <div className="aq-section-heading">
      <div>
        <p className="aq-eyebrow">The story so far</p>
        <h2>A product in motion.</h2>
      </div>
      <p>Built step by step.<br />Currently in pre-release development.</p>
    </div>
    <div className="aq-timeline">{milestones.slice(0, 3).map((milestone, index) => <article key={milestone.version}>
        <div className="aq-release-date">
          <span className="aq-version">v{milestone.version}</span>{index === 0 && <span className="aq-current">Latest milestone</span>}<time dateTime={milestone.date}>{new Date(`${milestone.date}T00:00:00+05:30`).toLocaleDateString('en-GB', {
              day: 'numeric',
              month: 'short',
              year: 'numeric',
              timeZone: 'Asia/Kolkata'
            })}</time>
        </div>
        <div>
          <h3>{milestone.title}</h3>
          <ul>{milestone.highlights.slice(0, index === 0 ? 3 : 2).map(text => <li key={text}>{text}</li>)}</ul>
        </div>
      </article>)}<details>
        <summary>Earlier development milestones <span>v{milestones.at(-1)?.version}–v{milestones[3]?.version}</span>
          <ChevronRight size={18} />
        </summary>{milestones.slice(3).map(milestone => <article key={milestone.version}>
          <div className="aq-release-date">
            <span className="aq-version">v{milestone.version}</span>
            <time dateTime={milestone.date}>{milestone.date}</time>
          </div>
          <div>
            <h3>{milestone.title}</h3>
            <p>{milestone.highlights[0]}</p>
          </div>
        </article>)}</details>
      <div className="aq-launch-milestone">
        <span className="aq-version">v1.0.0</span>
        <div>
          <strong>The first public release</strong>
          <p>Targeting 8 November 2026 · Google Play</p>
        </div>
        <span className="aq-reserved">Reserved · not released</span>
      </div>
    </div>
    <p className="aq-small">These are verified development milestones, not public release or deployment dates.</p>
  </section>;
}
export default function PublicLanding() {
  return <div className="aq-site">
    <a className="aq-skip" href="#main">Skip to content</a>
    <header className="aq-header aq-container">
      <a href="#" aria-label="AptiQu home">
        <Brand />
      </a>
      <nav aria-label="Main navigation">
        <a href="#features">Features</a>
        <a href="#preview">App preview</a>
        <a href="#next">What’s next</a>
        <a href="#updates">Updates</a>
      </nav>
      <span className="aq-header-status">
        <span /> In the making</span>
    </header>
    <main id="main">
      <section className="aq-hero aq-container" aria-labelledby="hero-title">
        <div className="aq-hero-copy">
          <p className="aq-eyebrow">
            <span className="aq-mini-line" /> Learn. Practice. Rise.</p>
          <h1 id="hero-title">Get better<br />at <span>aptitude.</span>
          </h1>
          <p className="aq-hero-description">Learn the concepts.<br />Practice the patterns.<br />Compete with others.</p>
          <div className="aq-launch">
            <Sparkles size={22} aria-hidden="true" />
            <div>
              <strong>Coming this Diwali</strong>
              <span>
                <time dateTime="2026-11-08">8 November 2026</time>
                <i />Launching on Google Play</span>
            </div>
          </div>
          <a className="aq-text-link" href="#features">Find your edge <ArrowDown size={18} />
          </a>
        </div>
        <div className="aq-hero-art">
          <div className="aq-orbit aq-orbit-one" aria-hidden="true" />
          <div className="aq-orbit aq-orbit-two" aria-hidden="true" />
          <span className="aq-star aq-star-one" aria-hidden="true">✦</span>
          <span className="aq-star aq-star-two" aria-hidden="true">✦</span>
          <Phone priority entry={screenshot('ranked')} className="aq-hero-secondary" />
          <Phone priority entry={screenshot('home')} className="aq-hero-primary" />
          <span className="aq-hero-caption">A little better. Every day.</span>
        </div>
      </section>
      <div className="aq-principles aq-container" aria-label="Three ways to grow">
        <span>
          <b>01</b> Build understanding</span>
        <span>
          <b>02</b> Turn it into skill</span>
        <span>
          <b>03</b> Put it to the test</span>
      </div>
      <div className="aq-container">
        <section id="features" className="aq-section aq-learning">
          <div className="aq-learning-copy">
            <p className="aq-eyebrow">01 / Learn with clarity</p>
            <h2>Understand it<br />before you solve it.</h2>
            <p>Start with an idea, not a formula to memorise. Work through concepts, examples and guided questions, one step at a time.</p>
            <div className="aq-learning-steps">
              <div>
                <BookOpen size={19} />
                <span>Follow a structured topic path.</span>
              </div>
              <div>
                <Languages size={19} />
                <span>Read clear, worked explanations.</span>
              </div>
              <div>
                <Check size={19} />
                <span>Try it yourself, then see why it works.</span>
              </div>
            </div>
            <p className="aq-feature-footnote">Small steps. A stronger foundation.</p>
          </div>
          <div className="aq-lesson-art">
            <span className="aq-art-label">THE LEARNING EXPERIENCE</span>
            <Phone entry={screenshot('lesson')} />
            <div className="aq-math-note" aria-hidden="true">
              <span>Understand the why.</span>
              <strong>12 ÷ 3 = 4</strong>
              <span>Then make it yours.</span>
            </div>
          </div>
        </section>
        <section className="aq-section aq-practice">
          <div className="aq-practice-art">
            <Phone entry={screenshot('setup')} className="aq-setup-phone" />
            <Phone entry={screenshot('question')} className="aq-question-phone" />
          </div>
          <div className="aq-practice-copy">
            <p className="aq-eyebrow">02 / Make it stick</p>
            <h2>Practice<br />what matters.</h2>
            <p>Choose a subject, topic and subtopics—or mix it up with random practice. Set an optional timer and work through each question.</p>
            <div className="aq-practice-detail">
              <span>Find your focus</span>
              <p>Use Smart AI Picks to revisit patterns you found difficult.</p>
            </div>
            <div className="aq-practice-detail">
              <span>Learn from the attempt</span>
              <p>Review answer feedback and explanations. Follow your progress across sessions.</p>
            </div>
          </div>
        </section>
        <section className="aq-section aq-competition" aria-labelledby="compete-title">
          <div className="aq-competition-heading">
            <p className="aq-eyebrow">03 / A little friendly pressure</p>
            <h2 id="compete-title">Learn together.<br />
              <span>Compete seriously.</span>
            </h2>
            <p>A shared love of a good question.<br />A reason to bring your best.</p>
          </div>
          <div className="aq-compete-modes">
            <article>
              <span className="aq-mode-number">01 / Friendly duels</span>
              <h3>A friend. A challenge.<br />Your next good match.</h3>
              <p>Invite a friend to a Practice duel. Take on the same question set and compare your results when you both finish.</p>
            </article>
            <article>
              <span className="aq-mode-number">02 / Ranked competition</span>
              <h3>Find your level.<br />Then climb beyond it.</h3>
              <p>Play head to head, build your Elo rating and progress through the leagues. Monthly seasons give every climb its own story.</p>
            </article>
          </div>
          <div className="aq-ranks" aria-label="Ranked league progression">{['Unranked', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'].map((rank, i) => <figure key={rank}>
              <img src={`/showcase/ranks/rank_${rank.toLowerCase()}.webp`} alt={`${rank} rank badge`} width="144" height="144" loading="lazy" />
              <figcaption>
                <span>0{i + 1}</span>{rank}</figcaption>
            </figure>)}</div>
          <p className="aq-elo">
            <span>Elo, in plain English</span>Beat a stronger opponent and earn more rating. Your results—not just how many matches you play—determine your climb.</p>
        </section>
        <ScreenshotGallery />
        <ThemePreview />
        <section id="next" className="aq-section aq-roadmap">
          <div className="aq-section-heading">
            <div>
              <p className="aq-eyebrow">Still taking shape</p>
              <h2>We’re just<br />getting started.</h2>
            </div>
            <div>
              <span className="aq-planned">Planned / in development</span>
              <p>A look at where AptiQu is heading.<br />These features aren’t available yet;<br />timing may change.</p>
            </div>
          </div>
          <div className="aq-roadmap-list">{upcoming.map(({
              icon: Icon,
              title,
              label,
              text
            }, i) => <article key={label}>
              <div className="aq-roadmap-icon">
                <Icon size={21} strokeWidth={1.5} />
              </div>
              <div>
                <span className="aq-roadmap-label">0{i + 1} / {label}</span>
                <h3>{title}</h3>
                <p>{text}</p>
              </div>
            </article>)}</div>
        </section>
        <ReleaseTimeline />
        <section className="aq-developer" aria-labelledby="developer-title">
          <span className="aq-signature" aria-hidden="true">SK<span>↗</span>
          </span>
          <div>
            <p className="aq-eyebrow">An independent product</p>
            <h2 id="developer-title">Built by Shagun Kumar</h2>
            <p>Full-stack Software Engineer <span>·</span> 3 years of experience</p>
            <p className="aq-small">Working across mobile applications, backend systems and web platforms.</p>
          </div>
        </section>
      </div>
    </main>
    <footer className="aq-footer aq-container">
      <Brand />
      <span>A little better. Every day.</span>
      <small>© {new Date().getFullYear()} AptiQu</small>
    </footer>
  </div>;
}

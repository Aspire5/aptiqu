import React, { useEffect, useState } from 'react';
import { api } from '../services/api';
import { 
  Users, 
  Activity, 
  Flame, 
  Swords, 
  BrainCircuit, 
  TrendingUp, 
  CheckCircle2, 
  BookOpen
} from 'lucide-react';

export const DashboardPage: React.FC = () => {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [trendPeriod, setTrendPeriod] = useState<'daily' | 'weekly' | 'monthly'>('daily');

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    setLoading(true);
    try {
      const res = await api.getDashboardStats();
      if (res.data?.success) {
        setData(res.data.data);
      }
    } catch (err) {
      console.error('Failed to load dashboard data', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#7b809a' }}>
        <p>Loading SaaS intelligence metrics...</p>
      </div>
    );
  }

  const overview = data?.overview || {};
  const growthTrends = data?.growthTrends?.[trendPeriod] || [];
  const streakHistory = data?.dailyStreakHistory || [];
  const activity = overview?.activity || {};

  return (
    <div>
      {/* 1. TOP STAT CARDS WITH FLOATING GRADIENTS */}
      <div className="stats-grid">
        {/* Total Users */}
        <div className="stat-card">
          <div className="stat-card-header">
            <div className="stat-icon-box stat-icon-dark">
              <Users size={26} />
            </div>
            <div className="stat-card-info">
              <div className="stat-card-title">Total Users Registered</div>
              <div className="stat-card-value">{overview.totalUsers ?? 0}</div>
            </div>
          </div>
          <div className="stat-card-footer">
            <span className="stat-growth-positive">
              <TrendingUp size={14} style={{ display: 'inline', verticalAlign: 'middle', marginRight: 4 }} />
              All-Time Registered
            </span>
            <span>Total accounts</span>
          </div>
        </div>

        {/* Active in 24h */}
        <div className="stat-card">
          <div className="stat-card-header">
            <div className="stat-icon-box stat-icon-blue">
              <Activity size={26} />
            </div>
            <div className="stat-card-info">
              <div className="stat-card-title">Active Users (24 Hours)</div>
              <div className="stat-card-value">{overview.activeUsers24h ?? 0}</div>
            </div>
          </div>
          <div className="stat-card-footer">
            <span className="stat-growth-positive">
              {overview.totalUsers > 0 
                ? `${Math.round(((overview.activeUsers24h || 0) / overview.totalUsers) * 100)}%`
                : '0%'}
            </span>
            <span>24h active engagement</span>
          </div>
        </div>

        {/* Daily Streak Today */}
        <div className="stat-card">
          <div className="stat-card-header">
            <div className="stat-icon-box stat-icon-pink">
              <Flame size={26} />
            </div>
            <div className="stat-card-info">
              <div className="stat-card-title">Today's Daily Streak</div>
              <div className="stat-card-value">
                {overview.dailyStreak?.passedCount ?? 0} / {overview.dailyStreak?.attemptedCount ?? 0}
              </div>
            </div>
          </div>
          <div className="stat-card-footer">
            <span className="stat-growth-positive">
              {overview.dailyStreak?.passRate ?? 0}% Pass Rate
            </span>
            <span>All-or-None Challenge</span>
          </div>
        </div>

        {/* AI & Questions Generated */}
        <div className="stat-card">
          <div className="stat-card-header">
            <div className="stat-icon-box stat-icon-green">
              <BrainCircuit size={26} />
            </div>
            <div className="stat-card-info">
              <div className="stat-card-title">AI Questions Generated</div>
              <div className="stat-card-value">{activity.aiQuestionsGenerated ?? 0}</div>
            </div>
          </div>
          <div className="stat-card-footer">
            <span style={{ color: '#1a73e8', fontWeight: 700 }}>
              {activity.aiApiCallsMade ?? 0} API Calls
            </span>
            <span>Gemini pipeline</span>
          </div>
        </div>
      </div>

      {/* 2. AUTO-SCALING DOT-LINE GRAPH FOR USER GROWTH & ACTIVE USERS */}
      <div className="card">
        <div className="card-header-styled">
          <div>
            <h3 className="card-title">User Growth & Activity Velocity</h3>
            <p className="card-subtitle">
              Interactive auto-scaling line graph comparing new user registrations and active logged-in users
            </p>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            {(['daily', 'weekly', 'monthly'] as const).map((period) => (
              <button
                key={period}
                className={trendPeriod === period ? 'btn-primary' : 'btn-secondary'}
                style={{ padding: '6px 14px', fontSize: '12px' }}
                onClick={() => setTrendPeriod(period)}
              >
                {period === 'daily' ? 'Last 7 Days (Daily)' : period === 'weekly' ? 'Last 4 Weeks' : 'Last 12 Months'}
              </button>
            ))}
          </div>
        </div>

        {/* Responsive Auto-scaling SVG Line Graph */}
        <div style={{ width: '100%', position: 'relative', marginTop: '12px' }}>
          {(() => {
            const rawMax = Math.max(
              ...growthTrends.map((d: any) => Math.max(d.registered || 0, d.active || 0)),
              0
            );
            // Calculate dynamic ceiling so low counts never stick to the floor
            const yMax = rawMax === 0 ? 3 : (rawMax <= 3 ? rawMax + 1 : (rawMax <= 6 ? rawMax + 2 : Math.ceil(rawMax * 1.25)));

            const svgWidth = 840;
            const svgHeight = 250;
            const padLeft = 45;
            const padRight = 35;
            const padTop = 30;
            const padBottom = 40;
            const plotW = svgWidth - padLeft - padRight;
            const plotH = svgHeight - padTop - padBottom;

            const n = growthTrends.length;
            const getX = (i: number) => padLeft + (n > 1 ? (i / (n - 1)) * plotW : plotW / 2);
            const getY = (val: number) => padTop + plotH - (val / yMax) * plotH;

            // Coordinates for series
            const regPoints = growthTrends.map((d: any, i: number) => ({
              x: getX(i),
              y: getY(d.registered || 0),
              val: d.registered || 0,
              label: d.label,
            }));

            const actPoints = growthTrends.map((d: any, i: number) => ({
              x: getX(i),
              y: getY(d.active || 0),
              val: d.active || 0,
              label: d.label,
            }));

            const regLinePath = regPoints.length > 0 
              ? 'M ' + regPoints.map((p: any) => `${p.x},${p.y}`).join(' L ') 
              : '';
            const actLinePath = actPoints.length > 0 
              ? 'M ' + actPoints.map((p: any) => `${p.x},${p.y}`).join(' L ') 
              : '';

            const regAreaPath = regPoints.length > 0
              ? `${regLinePath} L ${regPoints[regPoints.length - 1].x},${padTop + plotH} L ${regPoints[0].x},${padTop + plotH} Z`
              : '';
            const actAreaPath = actPoints.length > 0
              ? `${actLinePath} L ${actPoints[actPoints.length - 1].x},${padTop + plotH} L ${actPoints[0].x},${padTop + plotH} Z`
              : '';

            // Y Ticks (4 levels: 0, 1/3, 2/3, max)
            const yTicks = [
              0,
              Math.max(1, Math.round(yMax / 3)),
              Math.max(2, Math.round((2 * yMax) / 3)),
              yMax,
            ].filter((val, idx, self) => self.indexOf(val) === idx);

            return (
              <svg 
                viewBox={`0 0 ${svgWidth} ${svgHeight}`} 
                style={{ width: '100%', height: '260px', overflow: 'visible' }}
              >
                <defs>
                  <linearGradient id="regGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#1a73e8" stopOpacity="0.25" />
                    <stop offset="100%" stopColor="#1a73e8" stopOpacity="0.0" />
                  </linearGradient>
                  <linearGradient id="actGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#4caf50" stopOpacity="0.22" />
                    <stop offset="100%" stopColor="#4caf50" stopOpacity="0.0" />
                  </linearGradient>
                </defs>

                {/* Horizontal Grid Lines & Y-Axis Labels */}
                {yTicks.map((tickVal) => {
                  const tickY = getY(tickVal);
                  return (
                    <g key={tickVal}>
                      <line
                        x1={padLeft}
                        y1={tickY}
                        x2={svgWidth - padRight}
                        y2={tickY}
                        stroke="#e2e8f0"
                        strokeDasharray="4 4"
                        strokeWidth="1"
                      />
                      <text
                        x={padLeft - 10}
                        y={tickY + 4}
                        textAnchor="end"
                        fontSize="11"
                        fill="#7b809a"
                        fontWeight="500"
                      >
                        {tickVal}
                      </text>
                    </g>
                  );
                })}

                {/* Shaded Areas */}
                {regAreaPath && <path d={regAreaPath} fill="url(#regGradient)" />}
                {actAreaPath && <path d={actAreaPath} fill="url(#actGradient)" />}

                {/* Lines */}
                {regLinePath && (
                  <path
                    d={regLinePath}
                    fill="none"
                    stroke="#1a73e8"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                )}
                {actLinePath && (
                  <path
                    d={actLinePath}
                    fill="none"
                    stroke="#4caf50"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                )}

                {/* Dots & Labels for Series 1: Registered Users */}
                {regPoints.map((p: any, i: number) => (
                  <g key={`reg-${i}`}>
                    <circle
                      cx={p.x}
                      cy={p.y}
                      r="5"
                      fill="#1a73e8"
                      stroke="#ffffff"
                      strokeWidth="2.5"
                    />
                    <text
                      x={p.x}
                      y={p.y - 10}
                      textAnchor="middle"
                      fontSize="10"
                      fontWeight="700"
                      fill="#1a73e8"
                    >
                      {p.val}
                    </text>
                  </g>
                ))}

                {/* Dots & Labels for Series 2: Active Users */}
                {actPoints.map((p: any, i: number) => (
                  <g key={`act-${i}`}>
                    <circle
                      cx={p.x}
                      cy={p.y}
                      r="5"
                      fill="#4caf50"
                      stroke="#ffffff"
                      strokeWidth="2.5"
                    />
                    <text
                      x={p.x}
                      y={p.y - 10}
                      textAnchor="middle"
                      fontSize="10"
                      fontWeight="700"
                      fill="#2e7d32"
                    >
                      {p.val}
                    </text>
                  </g>
                ))}

                {/* X-Axis Date Labels */}
                {growthTrends.map((d: any, i: number) => (
                  <text
                    key={`label-${i}`}
                    x={getX(i)}
                    y={padTop + plotH + 22}
                    textAnchor="middle"
                    fontSize="11"
                    fontWeight="500"
                    fill="#7b809a"
                  >
                    {d.label}
                  </text>
                ))}
              </svg>
            );
          })()}
        </div>

        {/* Legend */}
        <div style={{ display: 'flex', gap: '24px', justifyContent: 'center', marginTop: '16px', fontSize: '13px', color: '#7b809a' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '12px', height: '12px', background: '#1a73e8', borderRadius: '50%', display: 'inline-block' }}></span>
            <span style={{ fontWeight: 600, color: '#1a73e8' }}>New Registrations</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ width: '12px', height: '12px', background: '#4caf50', borderRadius: '50%', display: 'inline-block' }}></span>
            <span style={{ fontWeight: 600, color: '#2e7d32' }}>Active Logged-in Users</span>
          </div>
        </div>
      </div>

      {/* 3. HISTORIC DAILY STREAK CHALLENGE COMPARISON */}
      <div className="card">
        <div className="card-header-styled">
          <div>
            <h3 className="card-title">Daily Streak Challenge - Historic Difficulty Comparison</h3>
            <p className="card-subtitle">
              Analyzes completion rates across daily challenges to detect difficulty spikes
            </p>
          </div>
        </div>

        <div className="table-responsive">
          <table className="table-custom">
            <thead>
              <tr>
                <th>Challenge Date</th>
                <th>Total Attempts</th>
                <th>Passed</th>
                <th>Failed</th>
                <th>Pass Rate</th>
                <th>Avg Duration</th>
                <th>Relative Calibration</th>
              </tr>
            </thead>
            <tbody>
              {streakHistory.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', color: '#7b809a', padding: '24px' }}>
                    No daily streak challenge records yet.
                  </td>
                </tr>
              ) : (
                streakHistory.map((item: any, idx: number) => (
                  <tr key={idx}>
                    <td style={{ fontWeight: 600 }}>{item.dateString}</td>
                    <td>{item.totalAttempts}</td>
                    <td style={{ color: '#2e7d32', fontWeight: 600 }}>{item.passedCount}</td>
                    <td style={{ color: '#c62828' }}>{item.failedCount}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{ fontWeight: 700, width: '40px' }}>{item.passRate}%</span>
                        <div style={{
                          flex: 1,
                          height: '6px',
                          background: '#f0f2f5',
                          borderRadius: '3px',
                          overflow: 'hidden',
                          minWidth: '80px',
                        }}>
                          <div style={{
                            width: `${item.passRate}%`,
                            height: '100%',
                            background: item.passRate >= 70 ? '#4caf50' : item.passRate >= 45 ? '#ffa726' : '#ef5350',
                          }}></div>
                        </div>
                      </div>
                    </td>
                    <td>{item.avgTimeSeconds > 0 ? `${item.avgTimeSeconds}s` : 'N/A'}</td>
                    <td>
                      <span className={`badge ${
                        item.relativeDifficulty === 'EASIER' 
                          ? 'badge-success' 
                          : item.relativeDifficulty === 'HARDER' 
                          ? 'badge-danger' 
                          : 'badge-info'
                      }`}>
                        {item.relativeDifficulty}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* 4. ACTIVITY BREAKDOWN (PvP, Practice, Scripts, Replays) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '24px' }}>
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '8px', background: '#e3f2fd', color: '#1976d2', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Swords size={20} />
            </div>
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 700 }}>Ranked PvP Arena</h4>
              <p style={{ fontSize: '12px', color: '#7b809a' }}>Multiplayer real-time matches</p>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid #f0f2f5' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>Total Matches Created:</span>
            <span style={{ fontWeight: 700 }}>{activity.pvpMatchesPlayed ?? 0}</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>Matches Finished to Conclusion:</span>
            <span style={{ fontWeight: 700, color: '#4caf50' }}>{activity.pvpMatchesCompleted ?? 0}</span>
          </div>
        </div>

        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '8px', background: '#e8f5e9', color: '#2e7d32', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <CheckCircle2 size={20} />
            </div>
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 700 }}>Practice Arena</h4>
              <p style={{ fontSize: '12px', color: '#7b809a' }}>Solo adaptive training</p>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid #f0f2f5' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>Practice Sessions Played:</span>
            <span style={{ fontWeight: 700 }}>{activity.practiceMatchesPlayed ?? 0}</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>Matches Replayed (Mistake Review):</span>
            <span style={{ fontWeight: 700, color: '#1976d2' }}>{activity.matchesReplayed ?? 0}</span>
          </div>
        </div>

        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
            <div style={{ width: '40px', height: '40px', borderRadius: '8px', background: '#f3e5f5', color: '#7b1fa2', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <BookOpen size={20} />
            </div>
            <div>
              <h4 style={{ fontSize: '15px', fontWeight: 700 }}>Learning Scripts</h4>
              <p style={{ fontSize: '12px', color: '#7b809a' }}>Curriculum lesson completions</p>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid #f0f2f5' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>Curriculum Scripts Completed:</span>
            <span style={{ fontWeight: 700 }}>{activity.scriptsCompleted ?? 0}</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0' }}>
            <span style={{ fontSize: '13px', color: '#7b809a' }}>AI Conversations / Tutor Calls:</span>
            <span style={{ fontWeight: 700, color: '#7b1fa2' }}>{activity.aiApiCallsMade ?? 0}</span>
          </div>
        </div>
      </div>
    </div>
  );
};

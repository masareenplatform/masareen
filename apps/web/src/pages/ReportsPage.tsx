import React, { useEffect, useState } from 'react';
import { analyticsService } from '../services/api';

export default function ReportsPage() {
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  const fetchStats = async () => {
    try {
      const data = await analyticsService.platformSummary();
      setStats(data);
    } catch (e) {
      console.error('Error fetching analytics', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  if (loading) return <div className="p-8 text-muted">Loading reports...</div>;

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-ink mb-6">Platform Analytics</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="glass-card">
          <p className="text-muted text-sm">Total Verified Evidence</p>
          <p className="text-3xl font-bold text-ink">{stats?.total_evidence || 0}</p>
        </div>
        <div className="glass-card">
          <p className="text-muted text-sm">Active Programs</p>
          <p className="text-3xl font-bold text-ink">{stats?.active_programs || 0}</p>
        </div>
        <div className="glass-card">
          <p className="text-muted text-sm">Global Impact Score</p>
          <p className="text-3xl font-bold text-gold">{stats?.avg_impact_score || 0}</p>
        </div>
      </div>
      <div className="glass-card mt-8">
        <h2 className="text-xl font-semibold text-ink mb-4">SDG Progress</h2>
        <p className="text-muted">Platform-wide progress towards Sustainable Development Goals.</p>
        <div className="mt-4 h-40 rounded-xl bg-navy-100 flex items-center justify-center text-ink/40">
          Chart Visualization Placeholder
        </div>
      </div>
    </div>
  );
}

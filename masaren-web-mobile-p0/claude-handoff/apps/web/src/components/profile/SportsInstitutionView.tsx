import React from 'react';
import TimelineView from './TimelineView';

interface SportsInstitutionProps {
  name: string;
  league: string;
  division: string;
  trophies: any[];
  stadium: { name: string; capacity: number };
  timeline: any[];
  logoUrl?: string;
}

export default function SportsInstitutionView({ name, league, division, trophies, stadium, timeline, logoUrl }: SportsInstitutionProps) {
  return (
    <div className="space-y-8">
      <div className="relative h-64 rounded-3xl overflow-hidden bg-navy-900 text-white p-8 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <div className="w-24 h-24 rounded-2xl border-4 border-gold overflow-hidden bg-gray-200">
            {logoUrl ? <img src={logoUrl} alt={name} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-navy-900">{name[0]}</div>}
          </div>
          <div>
            <h1 className="text-5xl font-black mb-2">{name}</h1>
            <p className="text-xl text-gold font-medium">{league} • {division}</p>
          </div>
        </div>
        <div className="bg-gold text-navy-900 px-6 py-3 rounded-2xl font-black text-lg shadow-xl">
          OFFICIAL CLUB
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Infrastructure</h3>
            <div className="space-y-4">
              <div className="flex justify-between">
                <span className="text-gray-500">Stadium</span>
                <span className="font-medium">{stadium.name}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Capacity</span>
                <span className="font-bold text-navy-900">{stadium.capacity.toLocaleString()}</span>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Honors & Trophies</h3>
            <div className="space-y-3">
              {trophies.map((t, i) => (
                <div key={i} className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
                  <span className="text-xl">🏆</span>
                  <div>
                    <div className="font-bold text-sm">{t.name}</div>
                    <div className="text-xs text-gray-500">{t.year}</div>
                  </div>
                </div>
              ))}
              {trophies.length === 0 && <p className="text-gray-400 text-sm italic text-center">No trophies recorded yet</p>}
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 bg-white p-8 rounded-3xl shadow-sm border border-gray-100">
          <TimelineView events={timeline} title="Institutional History" />
        </div>
      </div>
    </div>
  );
}

import React from 'react';
import TimelineView from './TimelineView';

interface EducationInstitutionProps {
  name: string;
  accreditations: string[];
  ranking: number;
  specializations: string[];
  campuses: number;
  timeline: any[];
  logoUrl?: string;
}

export default function EducationInstitutionView({ name, accreditations, ranking, specializations, campuses, timeline, logoUrl }: EducationInstitutionProps) {
  return (
    <div className="space-y-8">
      <div className="relative h-64 rounded-3xl overflow-hidden bg-gradient-to-br from-navy-900 to-navy-800 text-white p-8 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <div className="w-24 h-24 rounded-2xl border-4 border-gold overflow-hidden bg-gray-200 shadow-xl">
            {logoUrl ? <img src={logoUrl} alt={name} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-navy-900">{name[0]}</div>}
          </div>
          <div>
            <h1 className="text-5xl font-black mb-2">{name}</h1>
            <p className="text-xl text-gold font-medium">Educational Institution</p>
          </div>
        </div>
        <div className="bg-white text-navy-900 px-6 py-3 rounded-2xl font-black text-center shadow-lg">
          <div className="text-xs uppercase font-bold text-gray-500">Global Rank</div>
          <div className="text-3xl">#{ranking}</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Accreditations</h3>
            <div className="space-y-3">
              {accreditations.map((acc, i) => (
                <div key={i} className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
                  <span className="text-lg">🎓</span>
                  <span className="text-sm font-medium text-gray-700">{acc}</span>
                </div>
              ))}
              {accreditations.length === 0 && <p className="text-gray-400 text-sm italic text-center">No accreditations listed</p>}
            </div>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Academic Focus</h3>
            <div className="flex flex-wrap gap-2">
              {specializations.map((spec, i) => (
                <span key={i} className="px-3 py-1 bg-navy-50 text-navy-700 rounded-full text-xs font-bold">
                  {spec}
                </span>
              ))}
            </div>
            <div className="mt-6 pt-6 border-t flex justify-between items-center">
              <span className="text-gray-500 text-sm">Total Campuses</span>
              <span className="font-bold text-navy-900">{campuses}</span>
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 bg-white p-8 rounded-3xl shadow-sm border border-gray-100">
          <TimelineView events={timeline} title="Academic History & Milestones" />
        </div>
      </div>
    </div>
  );
}

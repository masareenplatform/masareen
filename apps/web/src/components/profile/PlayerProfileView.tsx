import React from 'react';
import TimelineView from './TimelineView';

interface PlayerProfileProps {
  name: string;
  position: string;
  jerseyNumber: number;
  nationality: string;
  birthDate: string;
  stats: Record<string, any>;
  timeline: any[];
  logoUrl?: string;
}

export default function PlayerProfileView({ name, position, jerseyNumber, nationality, birthDate, stats, timeline, logoUrl }: PlayerProfileProps) {
  return (
    <div className="space-y-8">
      <div className="relative h-64 rounded-3xl overflow-hidden bg-navy-900 text-white p-8 flex items-end">
        <div className="absolute top-0 right-0 p-8 opacity-20 text-9xl font-black">{jerseyNumber}</div>
        <div className="flex items-center gap-6 z-10">
          <div className="w-32 h-32 rounded-full border-4 border-gold overflow-hidden bg-gray-200">
            {logoUrl ? <img src={logoUrl} alt={name} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-4xl font-bold text-navy-900">{name[0]}</div>}
          </div>
          <div>
            <h1 className="text-5xl font-black mb-2">{name}</h1>
            <p className="text-xl text-gold font-medium">{position} • {nationality}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Personal Details</h3>
            <div className="space-y-4">
              <div className="flex justify-between">
                <span className="text-gray-500">Date of Birth</span>
                <span className="font-medium">{birthDate}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Jersey Number</span>
                <span className="font-bold text-navy-900">#{jerseyNumber}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Position</span>
                <span className="font-medium">{position}</span>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Career Stats</h3>
            <div className="grid grid-cols-2 gap-4">
              {Object.entries(stats).map(([key, value]) => (
                <div key={key} className="p-4 bg-gray-50 rounded-2xl text-center">
                  <div className="text-2xl font-black text-navy-900">{value}</div>
                  <div className="text-xs text-gray-500 uppercase font-bold">{key}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 bg-white p-8 rounded-3xl shadow-sm border border-gray-100">
          <TimelineView events={timeline} title="Professional Career" />
        </div>
      </div>
    </div>
  );
}

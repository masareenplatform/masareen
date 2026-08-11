import React from 'react';
import TimelineView from './TimelineView';

interface GovernmentInstitutionProps {
  name: string;
  jurisdiction: string;
  deptHead: string;
  transparency: number;
  services: string[];
  timeline: any[];
  logoUrl?: string;
}

export default function GovernmentInstitutionView({ name, jurisdiction, deptHead, transparency, services, timeline, logoUrl }: GovernmentInstitutionProps) {
  return (
    <div className="space-y-8">
      <div className="relative h-64 rounded-3xl overflow-hidden bg-slate-900 text-white p-8 flex items-center justify-between border-b-8 border-gold">
        <div className="flex items-center gap-6">
          <div className="w-24 h-24 rounded-full border-4 border-white overflow-hidden bg-gray-200">
            {logoUrl ? <img src={logoUrl} alt={name} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-navy-900">{name[0]}</div>}
          </div>
          <div>
            <h1 className="text-5xl font-black mb-2">{name}</h1>
            <p className="text-xl text-slate-300 font-medium">{jurisdiction}</p>
          </div>
        </div>
        <div className="bg-white text-slate-900 px-6 py-3 rounded-2xl font-black text-center shadow-xl">
          <div className="text-xs uppercase font-bold text-gray-500">Transparency Score</div>
          <div className="text-3xl">{transparency}%</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Leadership</h3>
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center font-bold text-gray-600">
                👤
              </div>
              <div>
                <div className="font-bold text-navy-800">{deptHead}</div>
                <div className="text-xs text-gray-500 uppercase font-bold">Department Head</div>
              </div>
            </div>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Public Services</h3>
            <div className="space-y-2">
              {services.map((service, i) => (
                <div key={i} className="flex items-center gap-3 p-2 hover:bg-gray-50 rounded-lg transition-colors cursor-pointer">
                  <span className="text-navy-900">🏛️</span>
                  <span className="text-sm font-medium text-gray-700">{service}</span>
                </div>
              ))}
              {services.length === 0 && <p className="text-gray-400 text-sm italic text-center">No services listed</p>}
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 bg-white p-8 rounded-3xl shadow-sm border border-gray-100">
          <TimelineView events={timeline} title="Governance & Legislative History" />
        </div>
      </div>
    </div>
  );
}

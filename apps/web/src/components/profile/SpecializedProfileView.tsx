import React from 'react';

interface TimelineEvent {
  date: string;
  title: string;
  description: string;
  metric?: string;
}

interface SpecializedProfileProps {
  type: 'PLAYER' | 'INSTITUTION' | 'GOV';
  name: string;
  timeline: TimelineEvent[];
  metrics: Record<string, any>;
}

export default function SpecializedProfileView({ type, name, timeline, metrics }: SpecializedProfileProps) {
  return (
    <div className="p-6 bg-white rounded-3xl shadow-lg border border-gray-100">
      <div className="flex items-center gap-4 mb-8">
        <div className="w-20 h-20 rounded-full bg-navy-900 text-white flex items-center justify-center text-2xl font-bold">
          {name[0]}
        </div>
        <div>
          <h2 className="text-3xl font-bold text-navy-900">{name}</h2>
          <p className="text-gray-500">{type === 'PLAYER' ? 'Professional Athlete' : 'Official Institution'}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-gray-50 p-4 rounded-2xl">
            <h3 className="font-bold mb-4 border-b pb-2">Core Metrics</h3>
            {Object.entries(metrics).map(([k, v]) => (
              <div key={k} className="flex justify-between py-2 text-sm">
                <span className="text-gray-600">{k}</span>
                <span className="font-bold">{v}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="lg:col-span-2">
          <h3 className="text-xl font-bold mb-6">Career Timeline</h3>
          <div className="relative border-l-4 border-gold ml-4 pl-8 space-y-8">
            {timeline.map((event, idx) => (
              <div key={idx} className="relative">
                <div className="absolute -left-[26px] top-1 w-4 h-4 rounded-full bg-navy-900 border-2 border-white" />
                <div className="flex justify-between items-start">
                  <span className="text-xs font-bold text-gray-400 uppercase">{event.date}</span>
                  {event.metric && <span className="text-xs bg-gold text-white px-2 py-1 rounded-full">{event.metric}</span>}
                </div>
                <h4 className="font-bold text-lg">{event.title}</h4>
                <p className="text-gray-600 text-sm">{event.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

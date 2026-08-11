import React from 'react';

interface TimelineEvent {
  date: string;
  title: string;
  description: string;
  metric?: string | number;
  mediaUrl?: string;
}

interface TimelineViewProps {
  events: TimelineEvent[];
  title?: string;
}

export default function TimelineView({ events, title = "Timeline" }: TimelineViewProps) {
  return (
    <div className="space-y-6">
      {title && <h3 className="text-2xl font-bold text-navy-900 mb-8">{title}</h3>}
      <div className="relative border-l-4 border-gold ml-4 pl-8 space-y-10">
        {events.map((event, idx) => (
          <div key={idx} className="relative group">
            <div className="absolute -left-[26px] top-1 w-4 h-4 rounded-full bg-navy-900 border-2 border-white transition-transform group-hover:scale-125" />
            <div className="flex justify-between items-start mb-2">
              <span className="text-sm font-bold text-gray-400 uppercase tracking-wider">{event.date}</span>
              {event.metric && (
                <span className="text-xs font-bold bg-gold text-white px-3 py-1 rounded-full shadow-sm">
                  {event.metric}
                </span>
              )}
            </div>
            <h4 className="font-bold text-xl text-navy-800 mb-2">{event.title}</h4>
            <p className="text-gray-600 leading-relaxed mb-4">{event.description}</p>
            {event.mediaUrl && (
              <div className="rounded-xl overflow-hidden border border-gray-200 shadow-sm max-w-md">
                <img src={event.mediaUrl} alt={event.title} className="w-full h-auto" />
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

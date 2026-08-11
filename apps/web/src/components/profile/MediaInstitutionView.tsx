import React from 'react';

interface MediaInstitutionProps {
  name: string;
  channels: string[];
  strategy: string;
  verification: string;
  handle: string;
  logoUrl?: string;
  recentContent: any[];
}

export default function MediaInstitutionView({ name, channels, strategy, verification, handle, logoUrl, recentContent }: MediaInstitutionProps) {
  return (
    <div className="space-y-8">
      <div className="relative h-64 rounded-3xl overflow-hidden bg-gradient-to-r from-navy-900 to-blue-800 text-white p-8 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <div className="w-24 h-24 rounded-full border-4 border-white overflow-hidden bg-gray-200">
            {logoUrl ? <img src={logoUrl} alt={name} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-navy-900">{name[0]}</div>}
          </div>
          <div>
            <h1 className="text-5xl font-black mb-2">{name}</h1>
            <p className="text-xl text-blue-200 font-medium">{handle}</p>
          </div>
        </div>
        <div className="text-right">
          <div className="bg-white text-navy-900 px-4 py-2 rounded-xl font-bold text-sm shadow-lg mb-2">
            Verified {verification}
          </div>
          <div className="text-blue-200 text-sm font-medium">Media Network</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Distribution Channels</h3>
            <div className="flex flex-wrap gap-2">
              {channels.map((channel, i) => (
                <span key={i} className="px-3 py-1 bg-blue-50 text-blue-700 rounded-full text-xs font-bold uppercase">
                  {channel}
                </span>
              ))}
            </div>
          </div>

          <div className="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-bold text-navy-900 mb-6 border-b pb-4">Content Strategy</h3>
            <p className="text-gray-600 leading-relaxed text-sm">{strategy}</p>
          </div>
        </div>

        <div className="lg:col-span-2 space-y-6">
          <h3 className="text-2xl font-bold text-navy-900 mb-4">Recent Distribution</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {recentContent.map((content, i) => (
              <div key={i} className="bg-white rounded-2xl overflow-hidden border border-gray-100 shadow-sm group hover:shadow-md transition-shadow">
                <div className="h-40 bg-gray-200 relative">
                  <img src={content.mediaUrl} alt={content.title} className="w-full h-full object-cover" />
                  <div className="absolute top-3 right-3 bg-navy-900 text-white px-2 py-1 rounded text-xs font-bold uppercase">
                    {content.mediaType}
                  </div>
                </div>
                <div className="p-4">
                  <h4 className="font-bold text-navy-800 mb-2 group-hover:text-blue-600 transition-colors">{content.title}</h4>
                  <p className="text-gray-500 text-sm line-clamp-2 mb-4">{content.body}</p>
                  <div className="flex justify-between items-center">
                    <span className="text-xs font-bold text-gray-400">Reach: {content.reachCount.toLocaleString()}</span>
                    <span className="text-xs font-bold text-gold">Score: {content.engagementScore}</span>
                  </div>
                </div>
              </div>
            ))}
            {recentContent.length === 0 && <p className="text-gray-400 italic text-center col-span-2">No recent content available</p>}
          </div>
        </div>
      </div>
    </div>
  );
}

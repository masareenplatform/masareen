import React, { useEffect, useState } from 'react';
import { subscriptionService } from '../services/api';
import { useAuth } from '../store/authStore';

export default function BillingPage() {
  const { user } = useAuth();
  const [subscription, setSubscription] = useState<any>(null);
  const [plans, setPlans] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const [sub, planData] = await Promise.all([
        (user as any)?.organization_id
          ? subscriptionService.getForOrg((user as any).organization_id)
          : Promise.resolve(null),
        subscriptionService.plans().catch(() => null),
      ]);
      setSubscription(sub);
      setPlans(planData);
    } catch (e) {
      console.error('Error fetching subscription', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [(user as any)?.organization_id]);

  if (loading) return <div className="p-8 text-muted">Loading billing...</div>;

  const availablePlans = Array.isArray(plans?.plans ?? plans?.data)
    ? plans.plans ?? plans.data
    : [];

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-ink mb-6">Billing & Subscription</h1>
      <div className="glass-card max-w-2xl">
        <div className="flex justify-between items-center mb-6">
          <div>
            <p className="text-lg font-semibold text-ink">Current Plan: {subscription?.plan_name || 'Free'}</p>
            <p className="text-sm text-muted">Next billing date: {subscription?.next_billing_date || 'N/A'}</p>
          </div>
          <span className={`chip ${subscription?.status === 'ACTIVE' ? 'bg-emerald-400/15 text-emerald-600' : 'bg-rose-400/15 text-rose-600'}`}>
            {subscription?.status || 'INACTIVE'}
          </span>
        </div>
        <div className="border-t border-line/60 pt-6">
          <h3 className="font-semibold text-ink mb-4">Available Plans</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {(availablePlans.length ? availablePlans : [
              { name: 'Professional', price: '$29/mo' },
              { name: 'Enterprise', price: '$99/mo' },
            ]).map((p: any) => (
              <div key={p.name} className="glass rounded-xl p-4 hover:border-gold/40 transition cursor-pointer">
                <p className="font-bold text-ink">{p.name}</p>
                <p className="text-sm text-muted">{p.price}</p>
                <button className="btn-gold mt-4 w-full">
                  {p.name === 'Enterprise' ? 'Contact Sales' : 'Upgrade'}
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

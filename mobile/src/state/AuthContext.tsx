import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';

export type SessionStatus = 'unauthenticated' | 'guest' | 'authenticated';

type AuthContextValue = {
  status: SessionStatus;
  hasSeenOnboarding: boolean;
  completeOnboarding: () => void;
  // Simule une session le temps de valider écrans + navigation ; sera remplacé
  // par le vrai flux d'auth téléphone/PIN une fois Odoo branché (F02).
  loginAsUser: () => void;
  continueAsGuest: () => void;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<SessionStatus>('unauthenticated');
  const [hasSeenOnboarding, setHasSeenOnboarding] = useState(false);

  const completeOnboarding = useCallback(() => setHasSeenOnboarding(true), []);
  const loginAsUser = useCallback(() => setStatus('authenticated'), []);
  const continueAsGuest = useCallback(() => setStatus('guest'), []);
  const logout = useCallback(() => setStatus('unauthenticated'), []);

  const value = useMemo(
    () => ({ status, hasSeenOnboarding, completeOnboarding, loginAsUser, continueAsGuest, logout }),
    [status, hasSeenOnboarding, completeOnboarding, loginAsUser, continueAsGuest, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}

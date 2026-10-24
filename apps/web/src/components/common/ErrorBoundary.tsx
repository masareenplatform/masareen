import React from "react";

interface ErrorBoundaryProps {
  children: React.ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

/**
 * Catches uncaught render errors anywhere in the tree. Without this, a
 * single bad render (e.g. an unexpected API shape) blanks the entire app
 * to a white screen with no way back for the user.
 */
export default class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // eslint-disable-next-line no-console
    console.error("MASAREEN app crashed:", error, info.componentStack);
  }

  private handleReload = () => {
    this.setState({ error: null });
    window.location.href = "/dashboard";
  };

  render() {
    if (this.state.error) {
      return (
        <div className="grid min-h-screen place-items-center bg-canvas px-4 text-center">
          <div className="card max-w-md p-6">
            <h1 className="mb-2 text-xl font-bold text-ink">Something went wrong</h1>
            <p className="mb-4 text-sm text-muted">
              MASAREEN hit an unexpected error. Your data is safe, reloading usually fixes this.
            </p>
            <button className="btn-gold w-full" onClick={this.handleReload}>
              Reload
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

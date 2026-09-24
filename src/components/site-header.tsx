import { Link } from "@tanstack/react-router";
import { LayoutDashboard, Menu, X } from "lucide-react";
import { useState } from "react";
import { AuthDialog } from "@/components/auth-dialog";
import { Brand } from "@/components/brand";
import { ThemeToggle } from "@/components/theme-toggle";
import { AnimatePresence, motion } from "@/components/motion";
import { Button } from "@/components/ui/button";
import { useCurrentUser } from "@/hooks/use-portal";

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const { data: user, isLoading } = useCurrentUser();
  const signedIn = !!user;

  return (
    <motion.header
      initial={{ y: -64, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5, ease: [0.22, 0.9, 0.2, 1] }}
      className="sticky top-0 z-40 border-b border-border/70 bg-background/85 backdrop-blur-xl"
    >
      <div className="mx-auto grid h-16 max-w-7xl grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 sm:px-6 lg:flex">
        <Link to="/" className="min-w-0 lg:mr-auto">
          <Brand />
        </Link>
        <nav className="hidden items-center gap-6 text-sm font-semibold lg:flex">
          <Link to="/automations" className="transition-colors hover:text-primary">
            Automations
          </Link>
          <Link to="/checkout" className="transition-colors hover:text-primary">
            Pricing
          </Link>
          <Link to="/security" className="transition-colors hover:text-primary">
            Security
          </Link>
          <Link to="/status" className="transition-colors hover:text-primary">
            Status
          </Link>
          <Link to="/dashboard" className="transition-colors hover:text-primary">
            Dashboard
          </Link>
          <a href="mailto:antheticplusstudios@gmail.com" className="transition-colors hover:text-primary">
            Contact
          </a>
        </nav>
        <div className="flex shrink-0 items-center gap-1.5">
          <ThemeToggle />
          {!isLoading &&
            (signedIn ? (
              <Button asChild className="hidden sm:inline-flex">
                <Link to="/dashboard">
                  <LayoutDashboard className="h-4 w-4" />
                  My dashboard
                </Link>
              </Button>
            ) : (
              <>
                <AuthDialog mode="signin">
                  <Button variant="outline" className="hidden sm:inline-flex">
                    Sign in
                  </Button>
                </AuthDialog>
                <AuthDialog mode="signup">
                  <Button className="hidden sm:inline-flex">Get started</Button>
                </AuthDialog>
              </>
            ))}
          <Button
            variant="ghost"
            size="icon"
            className="lg:hidden"
            onClick={() => setOpen(!open)}
            aria-label="Open menu"
          >
            {open ? <X /> : <Menu />}
          </Button>
        </div>
      </div>
      <AnimatePresence initial={false}>
        {open && (
          <motion.nav
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.28, ease: [0.4, 0.14, 0.2, 1] }}
            className="grid gap-2 overflow-hidden border-t border-border px-4 lg:hidden"
          >
            <Link
              to="/automations"
              onClick={() => setOpen(false)}
              className="mt-3 rounded-lg px-3 py-2 font-semibold hover:bg-accent"
            >
              Automations
            </Link>
            <Link
              to="/checkout"
              onClick={() => setOpen(false)}
              className="rounded-lg px-3 py-2 font-semibold hover:bg-accent"
            >
              Pricing
            </Link>
            <Link
              to="/security"
              onClick={() => setOpen(false)}
              className="rounded-lg px-3 py-2 font-semibold hover:bg-accent"
            >
              Security
            </Link>
            <Link
              to="/status"
              onClick={() => setOpen(false)}
              className="rounded-lg px-3 py-2 font-semibold hover:bg-accent"
            >
              Status
            </Link>
            <Link
              to="/dashboard"
              onClick={() => setOpen(false)}
              className="rounded-lg px-3 py-2 font-semibold hover:bg-accent"
            >
              Dashboard
            </Link>
            {!signedIn && (
              <div className="mb-3 grid gap-2">
                <AuthDialog mode="signin">
                  <Button variant="outline" className="w-full">
                    Sign in
                  </Button>
                </AuthDialog>
                <AuthDialog mode="signup">
                  <Button className="w-full">Get started</Button>
                </AuthDialog>
              </div>
            )}
          </motion.nav>
        )}
      </AnimatePresence>
    </motion.header>
  );
}

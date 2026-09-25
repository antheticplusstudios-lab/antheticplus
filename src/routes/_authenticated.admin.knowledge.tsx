import { createFileRoute } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useMutation } from "@tanstack/react-query";
import { motion, AnimatePresence } from "motion/react";
import { BookOpenText, Check, Copy, Loader2, Save, Sparkles } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { AdminPage, Panel } from "@/components/admin-ui";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useAllInstances } from "@/hooks/use-admin";
import { generateKnowledgeDraft, saveKnowledgeDraft } from "@/lib/knowledge.functions";

export const Route = createFileRoute("/_authenticated/admin/knowledge")({
  head: () => ({
    meta: [
      { title: "Knowledge Drafts — AntheticPlus Control Center" },
      { name: "description", content: "Turn client website content into an AI receptionist knowledge base." },
    ],
  }),
  component: KnowledgeDrafts,
});

function KnowledgeDrafts() {
  const { data: instances = [] } = useAllInstances();
  const generate = useServerFn(generateKnowledgeDraft);
  const save = useServerFn(saveKnowledgeDraft);
  const [automationId, setAutomationId] = useState("");
  const [businessName, setBusinessName] = useState("");
  const [content, setContent] = useState("");
  const [draft, setDraft] = useState("");
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);

  const gen = useMutation({
    mutationFn: () => generate({ data: { content, businessName } }),
    onSuccess: (r: any) => {
      if (r.error) return setError(r.error);
      setError("");
      setDraft(r.draft);
      toast.success("Knowledge-base draft ready");
    },
    onError: (e: any) => setError(e?.message ?? "Generation failed"),
  });
  const saver = useMutation({
    mutationFn: () =>
      save({ data: { automationId, title: `AI draft — ${businessName || "knowledge base"}`, content: draft } }),
    onSuccess: () => toast.success("Saved to the automation's knowledge base"),
    onError: (e: any) => toast.error(e?.message ?? "Save failed"),
  });

  return (
    <AdminPage
      title="Knowledge Drafts"
      subtitle="Paste a customer's website content and AI writes a concise receptionist knowledge base — review, edit, then save it to their automation."
    >
      <div className="grid gap-6 xl:grid-cols-2">
        <Panel title="1 · Website content" description="Copy text from their site pages, menus, FAQs or brochures.">
          <div className="space-y-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <Input placeholder="Business name" value={businessName} onChange={(e) => setBusinessName(e.target.value)} />
              <select
                value={automationId}
                onChange={(e) => setAutomationId(e.target.value)}
                className="h-9 rounded-md border border-input bg-background px-3 text-sm"
              >
                <option value="">Link to automation (optional)</option>
                {instances.map((i: any) => (
                  <option key={i.id} value={i.id}>
                    {i.automation_slug} · {i.website_domain || "no domain"}
                  </option>
                ))}
              </select>
            </div>
            <Textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="Paste website content here…"
              className="min-h-[340px] font-mono text-xs"
            />
            <div className="flex items-center justify-between gap-3">
              <span className="text-xs tabular-nums text-muted-foreground">{content.length.toLocaleString()} / 60,000</span>
              <Button onClick={() => gen.mutate()} disabled={content.trim().length < 40 || gen.isPending}>
                {gen.isPending ? <Loader2 className="animate-spin" /> : <Sparkles />}
                {gen.isPending ? "Writing draft…" : "Generate draft"}
              </Button>
            </div>
            {error && (
              <p className="rounded-lg border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">{error}</p>
            )}
          </div>
        </Panel>

        <Panel
          title="2 · Receptionist knowledge base"
          description="Edit freely before saving."
          actions={
            draft && (
              <div className="flex gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    navigator.clipboard.writeText(draft);
                    setCopied(true);
                    setTimeout(() => setCopied(false), 1500);
                  }}
                >
                  {copied ? <Check /> : <Copy />} Copy
                </Button>
                <Button size="sm" onClick={() => saver.mutate()} disabled={!automationId || saver.isPending}>
                  {saver.isPending ? <Loader2 className="animate-spin" /> : <Save />} Save
                </Button>
              </div>
            )
          }
        >
          <AnimatePresence mode="wait">
            {gen.isPending ? (
              <motion.div key="load" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-3">
                {[90, 70, 85, 60, 75, 50].map((w, i) => (
                  <div key={i} className="h-3 animate-pulse rounded bg-muted" style={{ width: `${w}%` }} />
                ))}
              </motion.div>
            ) : draft ? (
              <motion.div key="draft" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
                <Textarea value={draft} onChange={(e) => setDraft(e.target.value)} className="min-h-[420px] text-sm leading-relaxed" />
                {!automationId && <p className="mt-2 text-xs text-muted-foreground">Pick an automation on the left to save.</p>}
              </motion.div>
            ) : (
              <motion.div key="empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="grid min-h-[340px] place-items-center text-center">
                <div>
                  <BookOpenText className="mx-auto h-10 w-10 text-muted-foreground/50" />
                  <p className="mt-3 text-sm text-muted-foreground">Your draft will appear here.</p>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </Panel>
      </div>
    </AdminPage>
  );
}

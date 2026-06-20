export default function Home() {
  return (
    <main>
      <section>
        <p className="eyebrow">Quick Text Family Server</p>
        <h1>Der Server ist bereit.</h1>
        <p>
          Dieser private Server verbindet registrierte Quick-Text-Geräte mit
          OpenAI, ohne den OpenAI-Key an die Geräte zu verteilen.
        </p>
        <dl>
          <div>
            <dt>Status</dt>
            <dd>API verfügbar</dd>
          </div>
          <div>
            <dt>Datenschutz</dt>
            <dd>Keine Speicherung von Audio oder Transkripten</dd>
          </div>
        </dl>
      </section>
    </main>
  );
}

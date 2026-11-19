return if Trailticket::Ticket.exists?

agent = Admin.create!(name: "Sergio (suporte)", role: "agent")
Admin.create!(name: "Paula (suporte)", role: "agent")
members = %w[Olivia Bruno Carla Diego Ester].map { |name| Admin.create!(name: name, role: "member") }
communities = ["Centro", "Vila Nova", "Jardim América", "Bela Vista"].map { |name| Community.create!(name: name) }

base = "https://app.comuh.test"

def trail(base, *steps)
  steps.each_with_index.map do |(type, path, label), i|
    { type: type, url: "#{base}#{path}", label: label, at: (30 - (i * 3)).minutes.ago.iso8601 }
  end
end

samples = [
  {
    title: "Botão de pagar não responde no checkout",
    body: "Cliquei em Pagar várias vezes e nada acontece.\nTentei no Chrome e no Firefox.",
    priority: "urgent", status: "open", days: 0,
    path: "/checkout?step=payment&token=abc123",
    trail: [["visit", "/planos", "Planos"], ["click", "/planos", 'button "Assinar Pro"'],
            ["visit", "/checkout?step=payment", "Checkout"], ["click", "/checkout?step=payment", 'button #pay "Pagar"']],
    fields: [{ name: "plan", label: "Plano", type: "select-one", value: "pro" },
             { name: "card_number", label: "Número do cartão", type: "text", value: "4111111111111111" }],
    errors: [{ type: "error", message: "TypeError: Cannot read properties of undefined (reading 'id')",
               source: "#{base}/assets/checkout.js", line: 120, column: 14 }],
    metadata: { comuhub: { admin: 12, comunidade: { id: 3, nome: "Centro", plano: "pro" } } }
  },
  {
    title: "Importação de CSV parou na linha 120",
    body: "O arquivo tem 800 linhas, importou só as primeiras 119.",
    priority: "high", status: "in_progress", days: 1,
    path: "/membros/importar",
    trail: [["visit", "/membros", "Membros"], ["click", "/membros", 'a "Importar"'],
            ["submit", "/membros/importar", "form action=/membros/importar"]],
    metadata: { comuhub: { admin: 7, comunidade: { id: 1, nome: "Vila Nova" }, arquivo: { linhas: 800, tamanho_kb: 96 } } }
  },
  {
    title: "Não consigo redefinir a senha",
    body: "O link do e-mail diz que expirou, mesmo clicando na hora.",
    priority: "high", status: "waiting", days: 2,
    path: "/senha/nova?reset_password_token=xyz789",
    trail: [["visit", "/entrar", "Entrar"], ["click", "/entrar", 'a "Esqueci a senha"'],
            ["visit", "/senha/nova?reset_password_token=xyz789", "Nova senha"]],
    fields: [{ name: "user[password]", type: "password", value: "segredo" }]
  },
  {
    title: "Relatório mensal com valores duplicados",
    body: "Em outubro, cada doação aparece duas vezes no total.",
    priority: "normal", status: "open", days: 3,
    path: "/relatorios/mensal?mes=2026-10",
    trail: [["visit", "/relatorios", "Relatórios"], ["click", "/relatorios", 'a "Mensal"']]
  },
  {
    title: "Erro 500 ao convidar membro",
    body: "Aparece a página de erro ao enviar o convite.",
    priority: "high", status: "closed", days: 6,
    path: "/convites/novo",
    trail: [["visit", "/membros", "Membros"], ["click", "/membros", 'a "Convidar"'], ["submit", "/convites", "form"]],
    errors: [{ type: "unhandledrejection", message: "HTTP 500" }]
  },
  {
    title: "Foto de perfil fica cortada",
    body: "A foto aparece cortada no topo em telas pequenas.",
    priority: "low", status: "open", days: 4, path: "/perfil"
  },
  {
    title: "Pedido: exportar lista de membros para Excel",
    body: "Seria ótimo exportar a lista filtrada.",
    priority: "low", status: "waiting", days: 9, path: "/membros?filtro=ativos"
  },
  {
    title: "Notificações chegando em duplicidade",
    body: "Cada aviso chega duas vezes no celular.",
    priority: "normal", status: "in_progress", days: 2, path: "/notificacoes",
    metadata: { comuhub: { dispositivo: { sistema: "Android 15", app: "2.4.1" } } }
  },
  {
    title: "Calendário mostra eventos no fuso errado",
    body: "Eventos às 19h aparecem às 22h.",
    priority: "normal", status: "closed", days: 12, path: "/eventos?mes=11", cancelled: true
  },
  {
    title: "Busca não encontra nomes com acento",
    body: "Procurar por \"João\" não retorna nada, \"Joao\" funciona.",
    priority: "normal", status: "open", days: 1, path: "/membros?q=Jo%C3%A3o",
    trail: [["visit", "/membros", "Membros"], ["submit", "/membros", "form busca"]]
  },
  {
    title: "Pagamento recusado sem mensagem",
    body: "O cartão foi recusado e a tela só recarregou.",
    priority: "urgent", status: "in_progress", days: 0, path: "/checkout?step=payment"
  },
  {
    title: "Texto do termo de uso desatualizado",
    body: "Ainda cita a versão de 2024.",
    priority: "low", status: "closed", days: 20, path: "/termos", archived: true
  },
  {
    title: "Dashboard demora para carregar",
    body: "Mais de 10 segundos de manhã.",
    priority: "normal", status: "waiting", days: 5, path: "/painel"
  },
  {
    title: "Convite aceito não aparece na lista",
    body: "O membro aceitou mas continua como pendente.",
    priority: "normal", status: "open", days: 2, path: "/membros?status=pendente"
  },
  {
    title: '<script>alert("xss")</script> título com HTML',
    body: '<img src=x onerror=alert(1)> o corpo também é escapado',
    priority: "low", status: "open", days: 7,
    url: "javascript:alert(document.cookie)",
    trail: [["visit", "/", "Início"]],
    extra_trail: [{ type: "click", url: "javascript:alert(2)", label: "<svg onload=alert(3)>" }],
    metadata: { teste: { html: "<b>negrito?</b>", link: "JaVaScRiPt:alert(4)" } }
  }
]

Trailticket::Current.actor = agent

config = Trailticket.config
work = config.statuses - [config.initial_status] - config.final_statuses
stage_status = lambda do |sample, i|
  case sample[:status]
  when "open" then config.triage && i.odd? ? work.first : config.initial_status
  when "in_progress" then work[1] || work.first
  when "waiting" then work.last
  else sample[:cancelled] ? (config.final_statuses[1] || config.final_statuses.first) : config.final_statuses.first
  end
end

samples.each_with_index do |sample, i|
  steps = sample[:trail] ? trail(base, *sample[:trail]) : []
  ticket = Trailticket.open_ticket(
    author: members[i % members.size],
    subject: (communities[i % communities.size] unless (i % 4).zero?),
    title: sample[:title],
    body: sample[:body],
    priority: sample[:priority] == "urgent" ? "high" : sample[:priority],
    user_agent: "Mozilla/5.0 (X11; Linux x86_64) Firefox/140.0",
    context: {
      page: { url: sample[:url] || "#{base}#{sample[:path]}", title: sample[:title].first(40),
              language: "pt-BR", timezone: "America/Sao_Paulo", viewport: "1440x900" },
      trail: steps + Array(sample[:extra_trail]),
      fields: sample[:fields] || [],
      errors: sample[:errors] || []
    },
    metadata: sample[:metadata] || {}
  )
  raise "Seed failed: #{ticket.errors.full_messages.to_sentence}" unless ticket.persisted?

  target = stage_status.call(sample, i)
  if i.even?
    ticket.messages.create!(author: agent, body: "Obrigado, estamos olhando.")
    ticket.messages.create!(author: agent, body: "Parece ligado ao deploy de ontem.", internal: true)
  end
  if config.triage && target != config.initial_status
    ticket.update!(priority: sample[:priority] == "urgent" ? "high" : sample[:priority])
  end
  path = config.statuses.take_while { |status| status != target }.drop(1) - config.final_statuses
  path << target unless target == ticket.status
  path.each do |status|
    ticket.update!(status: status, closed_by: (agent if config.final_statuses.include?(status)))
  end
  if ticket.priority && ticket.priority != sample[:priority]
    ticket.update!(priority: sample[:priority])
  end
  if i.odd?
    ticket.messages.create!(author: ticket.author, body: "Alguma novidade?")
  end
  ticket.archive! if sample[:archived]

  time = sample[:days].days.ago - (i * 37).minutes
  history = (ticket.events.to_a + ticket.messages.to_a).sort_by(&:created_at)
  history.each_with_index do |record, step|
    record.update_columns(created_at: time + ((step + 1) * 25).minutes)
  end
  last = history.last&.created_at || time
  closed = ticket.events.select { |e| e.action == "status_changed" && ticket.class.final_statuses.include?(e.to) }.last
  ticket.update_columns(created_at: time, updated_at: last,
                        closed_at: (closed&.created_at if ticket.final_status?),
                        archived_at: (last if ticket.archived?))
end

Trailticket::Current.reset

puts "Seeded #{Trailticket::Ticket.count} tickets."

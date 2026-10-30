require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api');

// Variáveis de ambiente
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const SOURCE_CHAT_ID = process.env.SOURCE_CHAT_ID ? String(process.env.SOURCE_CHAT_ID).trim() : null;
const TARGET_CHAT_ID = process.env.TARGET_CHAT_ID ? String(process.env.TARGET_CHAT_ID).trim() : null;
const CLONE_MODE = (process.env.CLONE_MODE || 'copy').toLowerCase(); // 'copy' ou 'forward'
const FILES_ONLY = (process.env.FILES_ONLY || 'true').toLowerCase() === 'true';

console.log('='.repeat(55));
console.log('      📁 TELEGRAM FILE TRANSFER & CLONER BOT');
console.log('='.repeat(55));

if (!TELEGRAM_BOT_TOKEN || TELEGRAM_BOT_TOKEN.includes('SEU_TELEGRAM_BOT_TOKEN')) {
  console.error('\n\x1b[31m[ERRO CRÍTICO]\x1b[0m O TELEGRAM_BOT_TOKEN não foi configurado no arquivo .env!');
  console.log('👉 Abra o arquivo .env e insira o token que você recebeu do @BotFather.\n');
  process.exit(1);
}

// Inicializa o bot com Long Polling
const bot = new TelegramBot(TELEGRAM_BOT_TOKEN, { polling: true });

// Formata o tamanho do arquivo em bytes para KB, MB ou GB
function formatFileSize(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
}

// Informações do Bot ao iniciar
bot.getMe().then((me) => {
  console.log(`\x1b[32m[Online]\x1b[0m Bot conectado como: @${me.username} (${me.first_name})`);
  console.log(`\x1b[36m[Modo de Envio]\x1b[0m: ${CLONE_MODE === 'copy' ? 'Cópia Limpa (sem etiqueta "Encaminhado")' : 'Encaminhamento Oficial'}`);
  console.log(`\x1b[36m[Filtro Exclusivo]\x1b[0m: ${FILES_ONLY ? 'Apenas Arquivos/Documentos (PDF, ZIP, APK, RAR, etc.)' : 'Todos os tipos'}`);
  
  if (SOURCE_CHAT_ID) {
    console.log(`\x1b[32m[Origem Configurada]\x1b[0m ID: ${SOURCE_CHAT_ID}`);
  } else {
    console.log(`\x1b[33m[Aviso Origem]\x1b[0m SOURCE_CHAT_ID não definido. O bot exibirá o ID de qualquer grupo onde falar.`);
  }

  if (TARGET_CHAT_ID) {
    console.log(`\x1b[32m[Destino Configurado]\x1b[0m ID: ${TARGET_CHAT_ID}`);
  } else {
    console.log(`\x1b[33m[Aviso Destino]\x1b[0m TARGET_CHAT_ID não definido no .env.`);
  }
  console.log('='.repeat(55));
  console.log('Monitorando arquivos no grupo de origem...\n');
}).catch((err) => {
  console.error('\x1b[31m[Erro de Conexão]\x1b[0m Falha ao conectar ao Telegram:', err.message);
});

// Escuta qualquer mensagem recebida
bot.on('message', async (msg) => {
  const chatId = String(msg.chat.id);
  const chatTitle = msg.chat.title || msg.chat.username || 'Chat Privado';

  // Comando utilitário /id para descobrir o ID do grupo
  if (msg.text && msg.text.startsWith('/id')) {
    bot.sendMessage(msg.chat.id, `📌 **ID deste chat:** \`${chatId}\`\n**Nome:** ${chatTitle}`, {
      parse_mode: 'Markdown'
    }).catch(() => {});
    return;
  }

  // Comando /status
  if (msg.text && msg.text.startsWith('/status')) {
    const statusMsg = `🤖 **Status do File Cloner:**\n\n` +
      `• **Origem:** \`${SOURCE_CHAT_ID || 'Não configurado'}\`\n` +
      `• **Destino:** \`${TARGET_CHAT_ID || 'Não configurado'}\`\n` +
      `• **Modo:** \`${CLONE_MODE}\`\n` +
      `• **Exclusivo para Arquivos:** \`${FILES_ONLY ? 'Sim' : 'Não'}\``;
    bot.sendMessage(msg.chat.id, statusMsg, { parse_mode: 'Markdown' }).catch(() => {});
    return;
  }

  // Se SOURCE_CHAT_ID ou TARGET_CHAT_ID não estiverem definidos, ajuda a exibir o ID no terminal
  if (!SOURCE_CHAT_ID || !TARGET_CHAT_ID) {
    console.log(`\x1b[33m[Dica de Configuração]\x1b[0m Mensagem recebida em: "${chatTitle}" | ID: \x1b[32m${chatId}\x1b[0m`);
  }

  // Filtra apenas mensagens vindas do grupo de Origem
  if (!SOURCE_CHAT_ID || chatId !== SOURCE_CHAT_ID) {
    return;
  }

  // Se o destino não estiver configurado, avisa
  if (!TARGET_CHAT_ID) {
    console.warn('\x1b[33m[Aviso]\x1b[0m Arquivo recebido na Origem, mas TARGET_CHAT_ID não está configurado no .env!');
    return;
  }

  // FILTRO: Apenas arquivos/documentos
  // No Telegram, anexos e arquivos são enviados como msg.document
  const document = msg.document;

  if (FILES_ONLY && !document) {
    // Ignora fotos normais de galeria, vídeos de streaming, áudios e mensagens de texto
    return;
  }

  const fileName = document?.file_name || `arquivo_${Date.now()}`;
  const fileSize = formatFileSize(document?.file_size);
  const mimeType = document?.mime_type || 'desconhecido';
  const senderName = [msg.from?.first_name, msg.from?.last_name].filter(Boolean).join(' ') || msg.from?.username || 'Anônimo';

  console.log(`\x1b[34m[Transferindo Arquivo]\x1b[0m`);
  console.log(`  📄 Nome: \x1b[36m${fileName}\x1b[0m`);
  console.log(`  ⚖️  Tamanho: ${fileSize}`);
  console.log(`  🏷️  MIME: ${mimeType}`);
  console.log(`  👤 Remetente: ${senderName}`);
  console.log(`  👥 De: "${chatTitle}" -> Para Destino`);

  try {
    if (CLONE_MODE === 'forward') {
      // Encaminha mantendo cabeçalho original
      await bot.forwardMessage(TARGET_CHAT_ID, msg.chat.id, msg.message_id);
    } else {
      // Clona/Copia o arquivo diretamente na nuvem do Telegram (sem etiqueta de encaminhamento e suportando até 2GB)
      await bot.copyMessage(TARGET_CHAT_ID, msg.chat.id, msg.message_id);
    }

    console.log(`\x1b[32m[Sucesso]\x1b[0m Arquivo "${fileName}" transferido com sucesso!\n`);
  } catch (err) {
    if (err.response && err.response.statusCode === 429) {
      const retryAfter = err.response.body?.parameters?.retry_after || 5;
      console.warn(`\x1b[33m[Rate Limit]\x1b[0m Limite de envio atingido. Aguardando ${retryAfter} segundos...`);
      setTimeout(async () => {
        try {
          await bot.copyMessage(TARGET_CHAT_ID, msg.chat.id, msg.message_id);
          console.log(`\x1b[32m[Sucesso]\x1b[0m Arquivo "${fileName}" transferido após espera.`);
        } catch (retryErr) {
          console.error('\x1b[31m[Falha]\x1b[0m Erro na nova tentativa:', retryErr.message);
        }
      }, retryAfter * 1000);
    } else {
      console.error('\x1b[31m[Erro na Transferência]\x1b[0m', err.message);
      if (err.message.includes('chat not found')) {
        console.error('👉 Verifique se o TARGET_CHAT_ID está correto e se o Bot foi adicionado como membro/administrador no grupo de destino!');
      }
    }
  }
});

// Tratamento de erros de polling
bot.on('polling_error', (error) => {
  if (error.code === 'ETELEGRAM' && error.message.includes('401')) {
    console.error('\x1b[31m[Erro 401]\x1b[0m Token do Telegram inválido! Verifique o TELEGRAM_BOT_TOKEN no .env');
  } else {
    console.error('\x1b[31m[Telegram Polling Error]\x1b[0m', error.message);
  }
});

// Finalização graciosa
process.on('SIGINT', () => {
  console.log('\nEncerrando bot...');
  bot.stopPolling().then(() => {
    process.exit(0);
  });
});

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_compress/video_compress.dart';

import 'premium_page.dart';
import 'purchase_service.dart';

const String politicaPrivacidadeUrl =
    'https://sites.google.com/view/snapshrink-politica/in%C3%ADcio';

Future<void> abrirPoliticaPrivacidade(BuildContext context) async {
  final url = Uri.parse(politicaPrivacidadeUrl);
  final abriu = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!abriu && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a Política de Privacidade.'),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const ReduzirApp());
}

class ReduzirApp extends StatelessWidget {
  const ReduzirApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF6750A4);
    return MaterialApp(
      title: 'SnapShrink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        scaffoldBackgroundColor: const Color(0xFFF8F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F7FB),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker picker = ImagePicker();
  final PurchaseService purchaseService = PurchaseService();

  XFile? arquivoEscolhido;
  String? tipoArquivo;
  String? arquivoReduzidoPath;
  int? tamanhoOriginal;
  int? tamanhoReduzido;
  String? mensagem;

  bool carregando = false;
  bool usuarioPremium = false;
  double progressoVideo = 0;
  Subscription? progressSubscription;

  BannerAd? bannerAd;
  bool bannerCarregado = false;
  InterstitialAd? interstitialAd;
  bool interstitialCarregado = false;
  bool interstitialCarregando = false;
  int contadorReducoesComSucesso = 0;
  static const int reducoesParaMostrarInterstitial = 3;

  String get bannerAdUnitId {
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    return 'ca-app-pub-5046960619406551/6517627295';
  }

  String get interstitialAdUnitId {
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return 'ca-app-pub-5046960619406551/3755732589';
  }

  @override
  void initState() {
    super.initState();
    carregarStatusPremium();
  }

  Future<void> carregarStatusPremium() async {
    await purchaseService.init();
    if (!mounted) return;
    final premium = purchaseService.isPremium;
    setState(() => usuarioPremium = premium);
    if (premium) {
      bannerAd?.dispose();
      interstitialAd?.dispose();
      bannerAd = null;
      interstitialAd = null;
      setState(() {
        bannerCarregado = false;
        interstitialCarregado = false;
      });
    } else {
      carregarBannerAd();
      carregarInterstitialAd();
    }
  }

  Future<void> abrirTelaPremium() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumPage()),
    );
    await carregarStatusPremium();
  }

  Future<void> compartilharApp() async {
    const link =
        'https://play.google.com/store/apps/details?id=com.macedourania.snapshrink';
    await Share.share(
      'Reduza imagens e vídeos de forma simples com o SnapShrink. $link',
      subject: 'SnapShrink',
    );
  }

  void carregarBannerAd() {
    if (usuarioPremium || bannerAd != null) return;
    bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => bannerCarregado = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          bannerAd = null;
        },
      ),
    )..load();
  }

  void carregarInterstitialAd() {
    if (usuarioPremium || interstitialCarregando || interstitialCarregado) {
      return;
    }
    interstitialCarregando = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialCarregando = false;
          interstitialAd = ad;
          interstitialCarregado = true;
        },
        onAdFailedToLoad: (_) {
          interstitialCarregando = false;
          interstitialAd = null;
        },
      ),
    );
  }

  void tentarMostrarInterstitialAd() {
    if (usuarioPremium) return;
    contadorReducoesComSucesso++;
    if (contadorReducoesComSucesso < reducoesParaMostrarInterstitial) return;
    contadorReducoesComSucesso = 0;
    if (interstitialAd != null && interstitialCarregado) {
      interstitialAd!.show();
      interstitialAd = null;
      interstitialCarregado = false;
    }
    carregarInterstitialAd();
  }

  Future<Directory> obterPastaSnapShrink() async {
    final base = await getApplicationDocumentsDirectory();
    final pasta = Directory('${base.path}${Platform.pathSeparator}SnapShrink');
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return pasta;
  }

  String formatarBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  double? get economiaPercentual {
    if (tamanhoOriginal == null || tamanhoReduzido == null || tamanhoOriginal == 0) {
      return null;
    }
    return (1 - (tamanhoReduzido! / tamanhoOriginal!)) * 100;
  }

  Future<void> _definirArquivo(XFile file, String tipo) async {
    final size = await File(file.path).length();
    if (!mounted) return;
    setState(() {
      arquivoEscolhido = file;
      tipoArquivo = tipo;
      tamanhoOriginal = size;
      tamanhoReduzido = null;
      arquivoReduzidoPath = null;
      mensagem = null;
      progressoVideo = 0;
    });
  }

  Future<void> escolherImagem() async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) await _definirArquivo(file, 'Imagem');
  }

  Future<void> escolherVideo() async {
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) await _definirArquivo(file, 'Vídeo');
  }

  void iniciarProgressoVideo() {
    progressoVideo = 0;
    progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
      if (mounted) setState(() => progressoVideo = progress.toDouble());
    });
  }

  void pararProgressoVideo() {
    progressSubscription?.unsubscribe();
    progressSubscription = null;
  }

  Future<void> reduzirImagem() async {
    setState(() {
      carregando = true;
      mensagem = 'Otimizando imagem…';
    });
    try {
      final bytes = await File(arquivoEscolhido!.path).readAsBytes();
      final imagem = img.decodeImage(bytes);
      if (imagem == null) throw Exception('Não foi possível ler a imagem.');
      final processada = imagem.width > 1280
          ? img.copyResize(imagem, width: 1280)
          : imagem;
      final reduzidos = img.encodeJpg(processada, quality: 75);
      final pasta = await obterPastaSnapShrink();
      final arquivo = File(
        '${pasta.path}/SnapShrink_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await arquivo.writeAsBytes(reduzidos);
      final size = await arquivo.length();
      if (!mounted) return;
      setState(() {
        arquivoReduzidoPath = arquivo.path;
        tamanhoReduzido = size;
        mensagem = 'Imagem otimizada com sucesso';
        carregando = false;
      });
      tentarMostrarInterstitialAd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        mensagem = 'Não foi possível reduzir esta imagem.';
        carregando = false;
      });
    }
  }

  Future<void> reduzirVideo() async {
    setState(() {
      carregando = true;
      mensagem = 'Comprimindo vídeo…';
    });
    iniciarProgressoVideo();
    try {
      final info = await VideoCompress.compressVideo(
        arquivoEscolhido!.path,
        quality: VideoQuality.MediumQuality,
      );
      if (info?.file == null) throw Exception('Compressão cancelada.');
      final size = await info!.file!.length();
      if (!mounted) return;
      setState(() {
        arquivoReduzidoPath = info.file!.path;
        tamanhoReduzido = size;
        mensagem = 'Vídeo otimizado com sucesso';
        carregando = false;
        progressoVideo = 100;
      });
      tentarMostrarInterstitialAd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        mensagem = 'Não foi possível reduzir este vídeo.';
        carregando = false;
      });
    } finally {
      pararProgressoVideo();
    }
  }

  bool get arquivoJaPequeno {
    if (tamanhoOriginal == null) return false;
    // Limites conservadores: apenas avisa, nunca bloqueia.
    if (tipoArquivo == 'Imagem') return tamanhoOriginal! <= 500 * 1024;
    if (tipoArquivo == 'Vídeo') return tamanhoOriginal! <= 2 * 1024 * 1024;
    return false;
  }

  Future<bool> confirmarReducaoDeArquivoPequeno() async {
    if (!arquivoJaPequeno) return true;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded),
        title: const Text('Este arquivo já está pequeno'),
        content: Text(
          'O arquivo selecionado tem ${formatarBytes(tamanhoOriginal)}. '
          'Uma nova redução pode gerar pouca economia ou diminuir a qualidade. '
          'Você ainda pode continuar se precisar de um arquivo menor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Escolher outro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar mesmo assim'),
          ),
        ],
      ),
    );
    return continuar ?? false;
  }

  Future<void> reduzirAgora() async {
    if (arquivoEscolhido == null || carregando) return;
    if (!await confirmarReducaoDeArquivoPequeno()) return;
    if (tipoArquivo == 'Imagem') {
      await reduzirImagem();
    } else {
      await reduzirVideo();
    }
  }

  Future<void> cancelarCompressao() async {
    await VideoCompress.cancelCompression();
    pararProgressoVideo();
    if (mounted) {
      setState(() {
        carregando = false;
        mensagem = 'Compressão cancelada.';
      });
    }
  }

  Future<void> compartilharArquivo() async {
    if (arquivoReduzidoPath == null) return;
    await Share.shareXFiles([XFile(arquivoReduzidoPath!)]);
  }

  Future<void> salvarNoDispositivo() async {
    if (arquivoReduzidoPath == null) return;
    try {
      final origem = File(arquivoReduzidoPath!);
      Directory? destino = await getDownloadsDirectory();
      destino ??= await getExternalStorageDirectory();
      destino ??= await getApplicationDocumentsDirectory();
      final extensao = arquivoReduzidoPath!.split('.').last;
      final nome = 'SnapShrink_${DateTime.now().millisecondsSinceEpoch}.$extensao';
      final salvo = await origem.copy('${destino.path}${Platform.pathSeparator}$nome');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo salvo em: ${salvo.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar. Use Compartilhar para escolher onde guardar o arquivo.'),
        ),
      );
    }
  }

  void limparSelecao() {
    setState(() {
      arquivoEscolhido = null;
      tipoArquivo = null;
      arquivoReduzidoPath = null;
      tamanhoOriginal = null;
      tamanhoReduzido = null;
      mensagem = null;
      progressoVideo = 0;
    });
  }

  @override
  void dispose() {
    pararProgressoVideo();
    purchaseService.dispose();
    bannerAd?.dispose();
    interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SnapShrink', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Reduza sem complicação',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (!usuarioPremium)
            IconButton(
              tooltip: 'Premium',
              onPressed: abrirTelaPremium,
              icon: const Icon(Icons.workspace_premium_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (value) {
              if (value == 'premium') abrirTelaPremium();
              if (value == 'privacy') abrirPoliticaPrivacidade(context);
              if (value == 'share') compartilharApp();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'premium',
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('SnapShrink Premium'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'privacy',
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Política de Privacidade'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.ios_share_outlined),
                  title: Text('Compartilhar app'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.compress_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 34,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Arquivos menores.\nCompartilhamento mais fácil.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Escolha uma imagem ou vídeo e o SnapShrink cuida do resto.',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withValues(alpha: .86),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              arquivoEscolhido == null ? 'O que você quer reduzir?' : 'Arquivo selecionado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (arquivoEscolhido == null)
              Row(
                children: [
                  Expanded(
                    child: _SelectCard(
                      icon: Icons.image_outlined,
                      title: 'Imagem',
                      subtitle: 'JPG, PNG e mais',
                      onTap: escolherImagem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SelectCard(
                      icon: Icons.videocam_outlined,
                      title: 'Vídeo',
                      subtitle: 'Escolha da galeria',
                      onTap: escolherVideo,
                    ),
                  ),
                ],
              )
            else
              _FileCard(
                file: arquivoEscolhido!,
                type: tipoArquivo!,
                originalSize: formatarBytes(tamanhoOriginal),
                reducedSize: tamanhoReduzido == null
                    ? null
                    : formatarBytes(tamanhoReduzido),
                saving: economiaPercentual,
                onRemove: carregando ? null : limparSelecao,
              ),
            if (arquivoEscolhido != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: carregando ? null : reduzirAgora,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(
                  arquivoReduzidoPath == null ? 'Reduzir agora' : 'Reduzir novamente',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (carregando) ...[
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(mensagem ?? 'Processando…')),
                          if (tipoArquivo == 'Vídeo')
                            Text('${progressoVideo.toStringAsFixed(0)}%'),
                        ],
                      ),
                      if (tipoArquivo == 'Vídeo') ...[
                        const SizedBox(height: 14),
                        LinearProgressIndicator(value: progressoVideo / 100),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: cancelarCompressao,
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (!carregando && arquivoReduzidoPath != null) ...[
              const SizedBox(height: 18),
              _ResultCard(
                original: formatarBytes(tamanhoOriginal),
                reduced: formatarBytes(tamanhoReduzido),
                saving: economiaPercentual,
                onShare: compartilharArquivo,
                onSave: salvarNoDispositivo,
                onAnother: limparSelecao,
              ),
            ],
            if (!carregando && mensagem != null && arquivoReduzidoPath == null) ...[
              const SizedBox(height: 14),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Seus arquivos são processados no dispositivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: !usuarioPremium && bannerCarregado && bannerAd != null
          ? SafeArea(
              child: SizedBox(
                height: bannerAd!.size.height.toDouble(),
                width: bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: bannerAd!),
              ),
            )
          : null,
    );
  }
}

class _SelectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8E5EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 22),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final XFile file;
  final String type;
  final String originalSize;
  final String? reducedSize;
  final double? saving;
  final VoidCallback? onRemove;

  const _FileCard({
    required this.file,
    required this.type,
    required this.originalSize,
    required this.reducedSize,
    required this.saving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8E5EE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 70,
                height: 70,
                child: type == 'Imagem'
                    ? Image.file(File(file.path), fit: BoxFit.cover)
                    : Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 34,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Original: $originalSize',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (reducedSize != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Reduzido: $reducedSize',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remover',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String original;
  final String reduced;
  final double? saving;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onAnother;

  const _ResultCard({
    required this.original,
    required this.reduced,
    required this.saving,
    required this.onShare,
    required this.onSave,
    required this.onAnother,
  });

  @override
  Widget build(BuildContext context) {
    final value = saving ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCDEBD5)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF237A3B)),
              SizedBox(width: 9),
              Text(
                'Pronto!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Antes', value: original)),
              const Icon(Icons.arrow_forward_rounded, color: Colors.black38),
              Expanded(child: _Metric(label: 'Depois', value: reduced)),
            ],
          ),
          if (value > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Economia de ${value.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF237A3B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Você pode salvar, compartilhar ou reduzir outro arquivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Salvar no dispositivo'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Compartilhar arquivo'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onAnother,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reduzir outro arquivo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

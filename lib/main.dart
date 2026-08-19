import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_background_remover/image_background_remover.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const ShopeeApp());
}

class ShopeeApp extends StatelessWidget {
  const ShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
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
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _linkController =
      TextEditingController();

  late final Future<void> _backgroundInit;

  File? _imagemOriginal;

  Uint8List? _imagemProduto;

  Uint8List? _imagemCompartilhar;

  String _nomeProduto = '';

  String _preco = '';

  String _textoLido = '';

  bool _carregando = false;

  String _status = '';

  @override
  void initState() {
    super.initState();

    _backgroundInit =
        BackgroundRemover.instance.initializeOrt();
  }

  @override
  void dispose() {
    _linkController.dispose();

    BackgroundRemover.instance.dispose();

    super.dispose();
  }

  // ============================================================
  // ESCOLHER PRINT
  // ============================================================

  Future<void> _escolherPrint() async {
    try {
      final XFile? arquivo =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (arquivo == null) {
        return;
      }

      setState(() {
        _imagemOriginal = File(arquivo.path);

        _imagemProduto = null;

        _imagemCompartilhar = null;

        _nomeProduto = '';

        _preco = '';

        _textoLido = '';

        _carregando = true;

        _status = 'Lendo o print...';
      });

      // ----------------------------------------------------------
      // OCR
      // ----------------------------------------------------------

      final RecognizedText resultado =
          await _reconhecerTexto(
        arquivo.path,
      );

      final String nome =
          _encontrarNomeProduto(resultado);

      final String preco =
          _encontrarPreco(resultado);

      final int limite =
          _encontrarLimiteDaFoto(resultado);

      if (!mounted) {
        return;
      }

      setState(() {
        _nomeProduto = nome;

        _preco = preco;

        _textoLido = resultado.text.trim();

        _status =
            'Recortando somente a área do produto...';
      });

      // ----------------------------------------------------------
      // PROCESSAR PRODUTO
      // ----------------------------------------------------------

      final Uint8List produtoPng =
          await _processarProduto(
        arquivo.path,
        limite,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _imagemProduto = produtoPng;

        _status =
            'Montando imagem para compartilhar...';
      });

      // ----------------------------------------------------------
      // CRIAR IMAGEM FINAL
      // ----------------------------------------------------------

      final Uint8List cardPng =
          await _criarImagemDeCompartilhamento(
        produtoPng,
        nome.isEmpty
            ? 'Produto Shopee'
            : nome,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _imagemCompartilhar = cardPng;

        _carregando = false;

        _status = '';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;

        _status = '';
      });

      _mostrarMensagem(
        'Não foi possível processar o print.\n\n$e',
      );
    }
  }

  // ============================================================
  // OCR
  // ============================================================

  Future<RecognizedText> _reconhecerTexto(
    String caminho,
  ) async {
    final TextRecognizer reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

      return await reconhecedor.processImage(
        imagem,
      );
    } finally {
      await reconhecedor.close();
    }
  }

  // ============================================================
  // NORMALIZAR TEXTO
  // ============================================================

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  // ============================================================
  // LIMPAR NOME
  // ============================================================

  String _limparTitulo(String texto) {
    String resultado =
        texto.replaceAll('\n', ' ');

    // Remove COMISSÃO EXTRA
    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      '',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comissao\s*extra',
        caseSensitive: false,
      ),
      '',
    );

    resultado = resultado.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      '',
    );

    // Remove porcentagens
    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d{1,2}(?:[,.]\d+)?\s*%',
      ),
      '',
    );

    // Remove preços
    resultado = resultado.replaceAll(
      RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      ),
      '',
    );

    resultado =
        resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    ).trim();

    return resultado;
  }

  // ============================================================
  // IGNORAR TEXTOS DA SHOPEE
  // ============================================================

  bool _ehTextoDeInterface(
    String texto,
  ) {
    final String t =
        _normalizar(texto);

    const List<String> ignorados = [
      'shopee',
      'comprar',
      'oferta',
      'frete',
      'cupom',
      'avaliacao',
      'avaliacoes',
      'vendido',
      'parcelado',
      'entrega',
      'compartilhar',
      'adicionar ao carrinho',
      'comprar agora',
      'aprenda com outros criadores',
      'afiliados promoveram',
      'mil vendido',
      'comissao',
      'comissao extra',
      'variacoes',
      'variacao',
    ];

    for (final String palavra in ignorados) {
      if (t.contains(palavra)) {
        return true;
      }
    }

    if (RegExp(
      r'^\d+[,.]?\d*\s*$',
    ).hasMatch(t)) {
      return true;
    }

    if (RegExp(
      r'^\d+\s*%$',
    ).hasMatch(t)) {
      return true;
    }

    return false;
  }

  // ============================================================
  // ENCONTRAR NOME DO PRODUTO
  // ============================================================

  String _encontrarNomeProduto(
    RecognizedText resultado,
  ) {
    final RegExp regexPreco =
        RegExp(
      r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
      caseSensitive: false,
    );

    double? topoPreco;

    // Descobre onde aparece o preço.
    for (final TextBlock bloco
        in resultado.blocks) {
      if (regexPreco.hasMatch(
        bloco.text,
      )) {
        topoPreco ??=
            bloco.boundingBox.top;
      }
    }

    String melhor = '';

    double melhorPontuacao = -999;

    // Analisa os blocos reconhecidos pelo OCR.
    for (final TextBlock bloco
        in resultado.blocks) {
      String candidato =
          _limparTitulo(
        bloco.text,
      );

      if (candidato.isEmpty) {
        continue;
      }

      if (_ehTextoDeInterface(
        candidato,
      )) {
        continue;
      }

      final String normalizado =
          _normalizar(candidato);

      final List<String> palavras =
          candidato
              .split(RegExp(r'\s+'))
              .where(
                (p) => p.trim().isNotEmpty,
              )
              .toList();

      // Não aceita palavras isoladas.
      if (palavras.length < 2) {
        continue;
      }

      if (candidato.length < 10) {
        continue;
      }

      if (candidato.length > 180) {
        candidato =
            candidato.substring(
          0,
          180,
        ).trim();
      }

      double pontuacao = 0;

      pontuacao +=
          palavras.length * 2;

      pontuacao +=
          candidato.length / 20;

      // O título normalmente aparece depois do preço.
      if (topoPreco != null &&
          bloco.boundingBox.top >
              topoPreco!) {
        pontuacao += 20;
      }

      // Palavras que normalmente aparecem em nomes de produtos.
      if (normalizado.contains(
            'oximetro',
          ) ||
          normalizado.contains(
            'cartao',
          ) ||
          normalizado.contains(
            'memoria',
          ) ||
          normalizado.contains(
            'micro sd',
          ) ||
          normalizado.contains(
            'ssd',
          ) ||
          normalizado.contains(
            'fone',
          ) ||
          normalizado.contains(
            'mouse',
          ) ||
          normalizado.contains(
            'teclado',
          ) ||
          normalizado.contains(
            'celular',
          ) ||
          normalizado.contains(
            'carregador',
          ) ||
          normalizado.contains(
            'camera',
          ) ||
          normalizado.contains(
            'relogio',
          )) {
        pontuacao += 10;
      }

      if (pontuacao >
          melhorPontuacao) {
        melhorPontuacao =
            pontuacao;

        melhor = candidato;
      }
    }

    // Último recurso.
    if (melhor.isEmpty) {
      final List<String> linhas =
          resultado.text
              .split('\n')
              .map(
                _limparTitulo,
              )
              .where(
                (linha) =>
                    linha.length >= 10 &&
                    !_ehTextoDeInterface(
                      linha,
                    ),
              )
              .toList();

      if (linhas.isNotEmpty) {
        melhor = linhas.first;
      }
    }

    return melhor;
  }

  // ============================================================
  // ENCONTRAR PREÇO
  // ============================================================

  String _encontrarPreco(
    RecognizedText resultado,
  ) {
    final RegExp regexPreco =
        RegExp(
      r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
      caseSensitive: false,
    );

    final List<String> precos = [];

    for (final TextBlock bloco
        in resultado.blocks) {
      final Iterable<Match> matches =
          regexPreco.allMatches(
        bloco.text,
      );

      for (final Match match
          in matches) {
        String valor =
            match.group(0) ?? '';

        valor =
            valor.replaceAll(
          RegExp(r'\s+'),
          '',
        );

        if (valor.isNotEmpty &&
            !precos.contains(valor)) {
          precos.add(valor);
        }
      }
    }

    if (precos.isEmpty) {
      return '';
    }

    return precos.first;
  }

  // ============================================================
  // ENCONTRAR FIM DA FOTO PRINCIPAL
  // ============================================================

  int _encontrarLimiteDaFoto(
    RecognizedText resultado,
  ) {
    double? limite;

    // Primeiro procura "variações".
    for (final TextBlock bloco
        in resultado.blocks) {
      final String t =
          _normalizar(bloco.text);

      if (t.contains('variacao')) {
        final double y =
            bloco.boundingBox.top - 18;

        if (y > 250) {
          limite = y;

          break;
        }
      }
    }

    // Se não encontrou "variações",
    // procura o primeiro preço.
    if (limite == null) {
      final RegExp regexPreco =
          RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      for (final TextBlock bloco
          in resultado.blocks) {
        if (regexPreco.hasMatch(
          bloco.text,
        )) {
          final double y =
              bloco.boundingBox.top - 18;

          if (y > 250) {
            limite = y;

            break;
          }
        }
      }
    }

    // Se o OCR não encontrar nada,
    // o processamento usará um fallback.
    return limite?.round() ?? 0;
  }

  // ============================================================
  // RECORTAR + REMOVER FUNDO
  // ============================================================

  Future<Uint8List> _processarProduto(
    String caminho,
    int limiteDetectado,
  ) async {
    await _backgroundInit;

    final Uint8List bytes =
        await File(caminho).readAsBytes();

    final img.Image? original =
        img.decodeImage(bytes);

    if (original == null) {
      throw Exception(
        'Não foi possível abrir a imagem.',
      );
    }

    int limite =
        limiteDetectado;

    // Se o OCR não encontrou o limite,
    // usa aproximadamente a metade superior.
    if (limite <= 0 ||
        limite > original.height) {
      limite =
          (original.height * 0.55)
              .round();
    }

    if (limite < 300) {
      limite = original.height;
    }

    if (limite > original.height) {
      limite = original.height;
    }

    // ----------------------------------------------------------
    // RECORTE DA PARTE PRINCIPAL
    // ----------------------------------------------------------

    final img.Image recorte =
        img.copyCrop(
      original,
      x: 0,
      y: 0,
      width: original.width,
      height: limite,
    );

    // ----------------------------------------------------------
    // REDUZ IMAGEM MUITO GRANDE
    // ----------------------------------------------------------

    img.Image imagemParaIA =
        recorte;

    const int maiorLado = 1800;

    if (imagemParaIA.width >
            maiorLado ||
        imagemParaIA.height >
            maiorLado) {
      if (imagemParaIA.width >=
          imagemParaIA.height) {
        imagemParaIA =
            img.copyResize(
          imagemParaIA,
          width: maiorLado,
        );
      } else {
        imagemParaIA =
            img.copyResize(
          imagemParaIA,
          height: maiorLado,
        );
      }
    }

    final Uint8List recortePng =
        Uint8List.fromList(
      img.encodePng(
        imagemParaIA,
      ),
    );

    // ----------------------------------------------------------
    // REMOVE FUNDO
    // ----------------------------------------------------------

    final ui.Image imagemSemFundo =
        await BackgroundRemover
            .instance
            .removeBg(
      recortePng,
      threshold: 0.45,
      smoothMask: true,
      enhanceEdges: true,
    );

    final ByteData? dados =
        await imagemSemFundo.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (dados == null) {
      throw Exception(
        'Não foi possível processar o produto.',
      );
    }

    return dados.buffer
        .asUint8List();
  }

  // ============================================================
  // CRIAR IMAGEM FINAL
  // ============================================================

  Future<Uint8List>
      _criarImagemDeCompartilhamento(
    Uint8List produtoBytes,
    String nome,
  ) async {
    final ui.Codec codec =
        await ui.instantiateImageCodec(
      produtoBytes,
    );

    final ui.FrameInfo frame =
        await codec.getNextFrame();

    final ui.Image produto =
        frame.image;

    const double largura = 1080;

    const double alturaFoto = 760;

    const double margem = 50;

    // ----------------------------------------------------------
    // TEXTO DO NOME
    // ----------------------------------------------------------

    final TextPainter titulo =
        TextPainter(
      text: TextSpan(
        text: nome,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight:
              FontWeight.bold,
          height: 1.15,
        ),
      ),
      textAlign:
          TextAlign.center,
      textDirection:
          TextDirection.ltr,
      maxLines: 5,
      ellipsis: '...',
    );

    titulo.layout(
      maxWidth:
          largura - (margem * 2),
    );

    final double alturaFaixa =
        (titulo.height + 80)
            .clamp(
      170.0,
      430.0,
    );

    final double alturaTotal =
        alturaFoto +
            alturaFaixa;

    // ----------------------------------------------------------
    // CANVAS
    // ----------------------------------------------------------

    final ui.PictureRecorder
        recorder =
        ui.PictureRecorder();

    final Canvas canvas =
        Canvas(recorder);

    final Paint branco =
        Paint()
          ..color =
              Colors.white;

    final Paint verde =
        Paint()
          ..color =
              const Color(
            0xFF08603E,
          );

    // Fundo branco da foto.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        largura,
        alturaFoto,
      ),
      branco,
    );

    // Faixa verde.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        alturaFoto,
        largura,
        alturaFaixa,
      ),
      verde,
    );

    // ----------------------------------------------------------
    // AJUSTAR PRODUTO SEM DEFORMAR
    // ----------------------------------------------------------

    final double escalaX =
        (largura -
                margem * 2) /
            produto.width;

    final double escalaY =
        (alturaFoto -
                margem * 2) /
            produto.height;

    final double escala =
        escalaX < escalaY
            ? escalaX
            : escalaY;

    final double destinoLargura =
        produto.width * escala;

    final double destinoAltura =
        produto.height * escala;

    final double destinoX =
        (largura -
                destinoLargura) /
            2;

    final double destinoY =
        (alturaFoto -
                destinoAltura) /
            2;

    canvas.drawImageRect(
      produto,
      Rect.fromLTWH(
        0,
        0,
        produto.width
            .toDouble(),
        produto.height
            .toDouble(),
      ),
      Rect.fromLTWH(
        destinoX,
        destinoY,
        destinoLargura,
        destinoAltura,
      ),
      Paint()
        ..filterQuality =
            FilterQuality.high,
    );

    // ----------------------------------------------------------
    // NOME NA FAIXA VERDE
    // ----------------------------------------------------------

    titulo.paint(
      canvas,
      Offset(
        margem,
        alturaFoto + 40,
      ),
    );

    final ui.Picture picture =
        recorder.endRecording();

    final ui.Image imagemFinal =
        await picture.toImage(
      largura.toInt(),
      alturaTotal.toInt(),
    );

    final ByteData? dados =
        await imagemFinal.toByteData(
      format:
          ui.ImageByteFormat.png,
    );

    if (dados == null) {
      throw Exception(
        'Não foi possível criar a imagem final.',
      );
    }

    return dados.buffer
        .asUint8List();
  }

  // ============================================================
  // LINK
  // ============================================================

  String _obterLink() {
    String link =
        _linkController.text.trim();

    if (link.isEmpty) {
      return '';
    }

    if (!link.startsWith(
          'http://',
        ) &&
        !link.startsWith(
          'https://',
        )) {
      link =
          'https://$link';
    }

    return link;
  }

  // ============================================================
  // TEXTO DA DIVULGAÇÃO
  // ============================================================

  String _gerarTextoDivulgacao() {
    final String nome =
        _nomeProduto.isEmpty
            ? 'Produto Shopee'
            : _nomeProduto;

    final String preco =
        _preco.isEmpty
            ? 'Confira o preço'
            : _preco;

    final String link =
        _obterLink();

    return '''
🛍️ $nome

🔥 OFERTA NA SHOPEE 🔥

💰 $preco

👇 Confira aqui:
$link

🛒 Aproveite a oferta!
'''.trim();
  }

  // ============================================================
  // COMPARTILHAR
  // ============================================================

  Future<void> _compartilhar() async {
    final String link =
        _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado antes de compartilhar.',
      );

      return;
    }

    if (_imagemCompartilhar ==
        null) {
      _mostrarMensagem(
        'Escolha o print do produto primeiro.',
      );

      return;
    }

    try {
      final Directory pasta =
          await getTemporaryDirectory();

      final File arquivoFinal =
          File(
        '${pasta.path}/divulgacao_shopee.png',
      );

      await arquivoFinal
          .writeAsBytes(
        _imagemCompartilhar!,
        flush: true,
      );

      await SharePlus.instance.share(
        ShareParams(
          text:
              _gerarTextoDivulgacao(),
          subject:
              'Oferta Shopee - $_nomeProduto',
          files: [
            XFile(
              arquivoFinal.path,
              mimeType:
                  'image/png',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    }
  }

  // ============================================================
  // COMPARTILHAR SOMENTE TEXTO
  // ============================================================

  Future<void>
      _compartilharSomenteTexto() async {
    final String link =
        _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado primeiro.',
      );

      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text:
            _gerarTextoDivulgacao(),
      ),
    );
  }

  // ============================================================
  // LIMPAR
  // ============================================================

  void _limpar() {
    setState(() {
      _imagemOriginal = null;

      _imagemProduto = null;

      _imagemCompartilhar = null;

      _nomeProduto = '';

      _preco = '';

      _textoLido = '';

      _status = '';

      _linkController.clear();
    });
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(
    String mensagem,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(mensagem),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8F5),

      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.deepOrange,
        foregroundColor:
            Colors.white,
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            18,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              // ------------------------------------------------
              // LINK
              // ------------------------------------------------

              TextField(
                controller:
                    _linkController,
                keyboardType:
                    TextInputType.url,
                decoration:
                    InputDecoration(
                  labelText:
                      'Link do produto / link de afiliado',
                  hintText:
                      'Cole seu link aqui',
                  prefixIcon:
                      const Icon(
                    Icons.link,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      Colors.white,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // ------------------------------------------------
              // BOTÃO
              // ------------------------------------------------

              ElevatedButton.icon(
                onPressed:
                    _carregando
                        ? null
                        : _escolherPrint,
                icon:
                    const Icon(
                  Icons.photo_library,
                ),
                label:
                    const Text(
                  'ESCOLHER FOTO / PRINT DO PRODUTO',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                style:
                    ElevatedButton
                        .styleFrom(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 18,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ------------------------------------------------
              // CARREGANDO
              // ------------------------------------------------

              if (_carregando)
                Card(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      20,
                    ),
                    child:
                        Column(
                      children: [
                        const CircularProgressIndicator(),

                        const SizedBox(
                          height: 12,
                        ),

                        Text(
                          _status.isEmpty
                              ? 'Processando...'
                              : _status,
                          textAlign:
                              TextAlign
                                  .center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ------------------------------------------------
              // PRODUTO RECORTADO
              // ------------------------------------------------

              if (_imagemProduto !=
                      null &&
                  !_carregando)
                Card(
                  clipBehavior:
                      Clip.antiAlias,
                  child:
                      Column(
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets
                                .all(
                          12,
                        ),
                        child:
                            Row(
                          children: [
                            Icon(
                              Icons
                                  .auto_awesome,
                              color:
                                  Colors.deepOrange,
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                              'PRODUTO RECORTADO',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        color:
                            Colors.white,
                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),
                        child:
                            Image.memory(
                          _imagemProduto!,
                          height: 300,
                          width:
                              double.infinity,
                          fit: BoxFit
                              .contain,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 15,
              ),

              // ------------------------------------------------
              // IMAGEM FINAL
              // ------------------------------------------------

              if (_imagemCompartilhar !=
                      null &&
                  !_carregando)
                Card(
                  clipBehavior:
                      Clip.antiAlias,
                  child:
                      Column(
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets
                                .all(
                          12,
                        ),
                        child:
                            Row(
                          children: [
                            Icon(
                              Icons
                                  .share,
                              color:
                                  Colors.deepOrange,
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                              'IMAGEM QUE SERÁ COMPARTILHADA',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Image.memory(
                        _imagemCompartilhar!,
                        width:
                            double.infinity,
                        fit: BoxFit
                            .contain,
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 15,
              ),

              // ------------------------------------------------
              // INFORMAÇÕES
              // ------------------------------------------------

              if (!_carregando &&
                  (_nomeProduto
                          .isNotEmpty ||
                      _preco
                          .isNotEmpty))
                Card(
                  elevation: 2,
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      18,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style:
                              TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        const Text(
                          'NOME DO PRODUTO',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _nomeProduto
                                  .isEmpty
                              ? 'Não identificado'
                              : _nomeProduto,
                          style:
                              const TextStyle(
                            fontSize:
                                20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        const Text(
                          'PREÇO',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          _preco
                                  .isEmpty
                              ? 'Não identificado'
                              : _preco,
                          style:
                              const TextStyle(
                            fontSize:
                                22,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ------------------------------------------------
              // TEXTO DETECTADO
              // ------------------------------------------------

              if (_textoLido
                  .isNotEmpty)
                ExpansionTile(
                  title:
                      const Text(
                    'Ver texto detectado no print',
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        16,
                      ),
                      child:
                          SelectableText(
                        _textoLido,
                      ),
                    ),
                  ],
                ),

              const SizedBox(
                height: 12,
              ),

              // ------------------------------------------------
              // COMPARTILHAR
              // ------------------------------------------------

              if (_imagemCompartilhar !=
                  null)
                ElevatedButton.icon(
                  onPressed:
                      _compartilhar,
                  icon:
                      const Icon(
                    Icons.image,
                  ),
                  label:
                      const Text(
                    'COMPARTILHAR FOTO + DIVULGAÇÃO',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors
                            .deepOrange,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 18,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ------------------------------------------------
              // SOMENTE TEXTO
              // ------------------------------------------------

              if (_nomeProduto
                      .isNotEmpty ||
                  _preco
                      .isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      _compartilharSomenteTexto,
                  icon:
                      const Icon(
                    Icons.text_fields,
                  ),
                  label:
                      const Text(
                    'COMPARTILHAR SOMENTE TEXTO',
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ------------------------------------------------
              // LIMPAR
              // ------------------------------------------------

              if (_imagemOriginal !=
                  null)
                OutlinedButton.icon(
                  onPressed:
                      _limpar,
                  icon:
                      const Icon(
                    Icons.refresh,
                  ),
                  label:
                      const Text(
                    'LIMPAR',
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'O aplicativo tenta separar somente o produto, '
                'remove textos como COMISSÃO EXTRA do nome '
                'e cria uma nova imagem com o nome na faixa verde.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

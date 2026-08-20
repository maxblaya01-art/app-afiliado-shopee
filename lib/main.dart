import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  File? _imagemOriginal;
  File? _imagemRecortada;

  String _nomeProduto = '';
  String _preco = '';
  String _textoLido = '';

  bool _carregando = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  // ============================================================
  // ESCOLHER PRINT
  // ============================================================

  Future<void> _escolherPrint() async {
    try {
      final XFile? arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (arquivo == null) {
        return;
      }

      setState(() {
        _imagemOriginal = File(arquivo.path);
        _imagemRecortada = null;

        _nomeProduto = '';
        _preco = '';
        _textoLido = '';

        _carregando = true;
      });

      await _lerTextoDaImagem(arquivo.path);

      final File? recortada =
          await _recortarFotoPrincipal(arquivo.path);

      if (!mounted) return;

      setState(() {
        _imagemRecortada = recortada;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Não foi possível processar o print.\n\n$e',
      );
    }
  }

  // ============================================================
  // RECORTAR FOTO PRINCIPAL
  //
  // SOMENTE RECORTE.
  // NÃO REMOVE FUNDO.
  // ============================================================

  Future<File?> _recortarFotoPrincipal(String caminho) async {
    try {
      final File arquivo = File(caminho);

      final Uint8List bytes =
          await arquivo.readAsBytes();

      final img.Image? original =
          img.decodeImage(bytes);

      if (original == null) {
        return null;
      }

      final int largura = original.width;
      final int altura = original.height;

      final int topo =
          (altura * 0.035).round();

      final int finalFoto =
          (altura * 0.46).round();

      int alturaRecorte =
          finalFoto - topo;

      if (alturaRecorte < 100) {
        alturaRecorte = altura - topo;
      }

      final int margemHorizontal =
          (largura * 0.015).round();

      final int x = margemHorizontal;
      final int y = topo;

      final int larguraRecorte =
          largura - (margemHorizontal * 2);

      final int larguraFinal =
          larguraRecorte.clamp(
        1,
        largura - x,
      );

      final int alturaFinal =
          alturaRecorte.clamp(
        1,
        altura - y,
      );

      final img.Image recorte =
          img.copyCrop(
        original,
        x: x,
        y: y,
        width: larguraFinal,
        height: alturaFinal,
      );

      final List<int> jpg =
          img.encodeJpg(
        recorte,
        quality: 95,
      );

      final String novoCaminho =
          '${Directory.systemTemp.path}/produto_recortado_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File novoArquivo =
          File(novoCaminho);

      await novoArquivo.writeAsBytes(jpg);

      return novoArquivo;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // OCR
  // ============================================================

  Future<void> _lerTextoDaImagem(String caminho) async {
    final TextRecognizer reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final InputImage imagem =
          InputImage.fromFilePath(caminho);

      final RecognizedText resultado =
          await reconhecedor.processImage(imagem);

      final String texto =
          resultado.text.trim();

      // ----------------------------------------------------------
      // PEGA TODAS AS LINHAS DO OCR
      //
      // Importante:
      // usamos a posição vertical da linha para manter
      // a ordem correta do texto.
      // ----------------------------------------------------------

      final List<_LinhaOCR> linhasOCR = [];

      for (final TextBlock bloco in resultado.blocks) {
        for (final TextLine linha in bloco.lines) {
          linhasOCR.add(
            _LinhaOCR(
              texto: linha.text.trim(),
              topo: linha.boundingBox.top,
              esquerda: linha.boundingBox.left,
            ),
          );
        }
      }

      linhasOCR.sort(
        (a, b) {
          final int comparacaoVertical =
              a.topo.compareTo(b.topo);

          if (comparacaoVertical != 0) {
            return comparacaoVertical;
          }

          return a.esquerda.compareTo(
            b.esquerda,
          );
        },
      );

      final List<String> linhas =
          linhasOCR
              .map((linha) => linha.texto)
              .where(
                (linha) =>
                    linha.trim().isNotEmpty,
              )
              .toList();

      String nome = '';
      String preco = '';

      // ==========================================================
      // PREÇO
      // ==========================================================

      final RegExp regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      );

      int indicePreco = -1;

      for (int i = 0; i < linhas.length; i++) {
        final Match? match =
            regexPreco.firstMatch(linhas[i]);

        if (match != null) {
          final String linhaAtual =
              linhas[i].toLowerCase();

          // Dá preferência para uma linha
          // que realmente tenha R$.
          if (linhaAtual.contains('r\$')) {
            preco =
                match.group(0) ?? '';
            indicePreco = i;
            break;
          }

          // Guarda temporariamente qualquer preço.
          if (indicePreco == -1) {
            preco =
                match.group(0) ?? '';
            indicePreco = i;
          }
        }
      }

      // ==========================================================
      // FUNÇÕES AUXILIARES
      // ==========================================================

      bool linhaEhComissao(String linha) {
        final String t =
            linha
                .toLowerCase()
                .replaceAll(' ', '')
                .trim();

        return t.contains('comissãoextra') ||
            t.contains('comissaoextra') ||
            t == 'comissão' ||
            t == 'comissao';
      }

      bool linhaEhInterface(String linha) {
        final String t =
            linha.toLowerCase().trim();

        final List<String> palavras =
            [
          'shopee',
          'comprar',
          'oferta',
          'promoção',
          'promocao',
          'frete grátis',
          'frete gratis',
          'cupom',
          'avaliações',
          'avaliacoes',
          'parcelado',
          'entrega',
          'compartilhar',
          'adicionar ao carrinho',
          'comprar agora',
          'chat',
          'favoritar',
          'aprenda com outros criadores',
          'compartilhe para ganhar',
        ];

        for (final String palavra
            in palavras) {
          if (t.contains(palavra)) {
            return true;
          }
        }

        if (RegExp(
          r'\d+[,.]?\d*\s*%',
        ).hasMatch(t)) {
          return true;
        }

        return false;
      }

      bool linhaEhFimDoTitulo(String linha) {
        final String t =
            linha.toLowerCase().trim();

        // Essas informações aparecem
        // imediatamente depois do título.
        if (t.contains('afiliados')) {
          return true;
        }

        if (t.contains('promoveram')) {
          return true;
        }

        if (t.contains('vendido')) {
          return true;
        }

        if (t.contains('avaliação')) {
          return true;
        }

        if (t.contains('avaliacao')) {
          return true;
        }

        if (t.contains('estrelas')) {
          return true;
        }

        if (t.contains('mais vendidos')) {
          return true;
        }

        if (t.contains('mais vendido')) {
          return true;
        }

        if (t.contains('vendidos em')) {
          return true;
        }

        if (t.contains('shopee live')) {
          return true;
        }

        return false;
      }

      bool linhaEhRanking(String linha) {
        final String t =
            linha.toLowerCase().trim();

        // Exemplo:
        // No.11 Mais Vendidos...
        // No 11 Mais Vendidos...
        // Nº11 Mais Vendidos...
        if (RegExp(
          r'^(?:no\.?|nº|n°)\s*\d+',
          caseSensitive: false,
        ).hasMatch(t)) {
          return true;
        }

        return false;
      }

      // ==========================================================
      // ENCONTRAR NOME DO PRODUTO
      //
      // Agora NÃO limita o nome a somente 2 linhas.
      //
      // Isso corrige produtos grandes como:
      //
      // Projetor VEVSHAO A12 Android 13 Com 360° Rotação,
      // Suporte 4K, WiFi 6, Correção Keystone Automática E...
      //
      // O título pode ocupar 2, 3 ou até 4 linhas.
      // ==========================================================

      if (indicePreco >= 0) {
        final List<String> partesNome = [];

        bool encontrouPrimeiraParte =
            false;

        for (
          int i = indicePreco + 1;
          i < linhas.length;
          i++
        ) {
          final String linha =
              linhas[i].trim();

          if (linha.isEmpty) {
            continue;
          }

          // Comissão fica completamente fora
          // do nome do produto.
          if (linhaEhComissao(linha)) {
            continue;
          }

          // Se chegamos nas informações
          // de venda, terminamos o título.
          if (linhaEhFimDoTitulo(linha)) {
            break;
          }

          // Ranking da Shopee não faz parte
          // do produto.
          if (linhaEhRanking(linha)) {
            break;
          }

          // Ignora elementos conhecidos
          // da interface.
          if (linhaEhInterface(linha)) {
            continue;
          }

          // Não deixa preço entrar no título.
          if (regexPreco.hasMatch(linha)) {
            continue;
          }

          // Evita linhas muito pequenas.
          if (linha.length < 3) {
            continue;
          }

          // Evita textos absurdamente grandes
          // que normalmente são interface.
          if (linha.length > 220) {
            continue;
          }

          partesNome.add(linha);
          encontrouPrimeiraParte = true;

          // Até 4 linhas de título.
          if (partesNome.length >= 4) {
            break;
          }
        }

        if (encontrouPrimeiraParte) {
          nome = partesNome.join(' ');
        }
      }

      // ==========================================================
      // SEGUNDA TENTATIVA
      //
      // Se por algum motivo o OCR não encontrou
      // o preço corretamente, tenta encontrar
      // um título pela região central do texto.
      // ==========================================================

      if (nome.isEmpty) {
        final List<String> candidatos = [];

        for (final String linha
            in linhas) {
          final String t =
              linha.trim();

          if (t.isEmpty) {
            continue;
          }

          if (linhaEhComissao(t)) {
            continue;
          }

          if (linhaEhInterface(t)) {
            continue;
          }

          if (linhaEhRanking(t)) {
            continue;
          }

          if (linhaEhFimDoTitulo(t)) {
            continue;
          }

          if (regexPreco.hasMatch(t)) {
            continue;
          }

          if (t.length < 5) {
            continue;
          }

          if (t.length > 220) {
            continue;
          }

          candidatos.add(t);
        }

        // Em vez de pegar somente a maior linha,
        // tentamos formar um título com as linhas
        // mais próximas umas das outras.
        if (candidatos.isNotEmpty) {
          final List<String> melhores =
              candidatos.take(4).toList();

          nome =
              melhores.join(' ');
        }
      }

      // ==========================================================
      // LIMPEZA FINAL DO NOME
      // ==========================================================

      nome = _limparNomeProduto(nome);

      if (!mounted) return;

      setState(() {
        _textoLido = texto;
        _nomeProduto = nome;
        _preco =
            _normalizarPreco(preco);
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Erro ao reconhecer o texto do print.\n\n$e',
      );
    } finally {
      await reconhecedor.close();
    }
  }

  // ============================================================
  // LIMPAR NOME DO PRODUTO
  // ============================================================

  String _limparNomeProduto(String nome) {
    String resultado =
        nome.trim();

    // Remove comissão mesmo quando
    // o OCR junta as palavras.
    resultado =
        resultado.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      '',
    );

    resultado =
        resultado.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      '',
    );

    // Remove percentuais.
    resultado =
        resultado.replaceAll(
      RegExp(
        r'\b\d+[,.]?\d*\s*%',
        caseSensitive: false,
      ),
      '',
    );

    // Remove ranking no começo.
    resultado =
        resultado.replaceFirst(
      RegExp(
        r'^\s*(?:no\.?|nº|n°)\s*\d+\s*[,.\-:]?\s*',
        caseSensitive: false,
      ),
      '',
    );

    // Se por algum erro o texto de
    // "Mais Vendidos" entrou no nome,
    // corta a partir dali.
    final RegExp fimRanking =
        RegExp(
      r'\s*(?:mais\s+vendidos?|vendidos\s+em)\b.*$',
      caseSensitive: false,
    );

    resultado =
        resultado.replaceFirst(
      fimRanking,
      '',
    );

    // Remove informações de afiliados
    // caso tenham escapado.
    resultado =
        resultado.replaceFirst(
      RegExp(
        r'\s*(?:\d+\s*)?afiliados?\b.*$',
        caseSensitive: false,
      ),
      '',
    );

    // Remove espaços duplicados.
    resultado =
        resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // Corrige espaços antes de pontuação.
    resultado =
        resultado.replaceAll(
      RegExp(r'\s+([,.!?])'),
      r'$1',
    );

    return resultado.trim();
  }

  // ============================================================
  // NORMALIZAR PREÇO
  // ============================================================

  String _normalizarPreco(
    String preco,
  ) {
    String resultado =
        preco.trim();

    if (resultado.isEmpty) {
      return '';
    }

    if (!resultado
        .toLowerCase()
        .contains('r\$')) {
      resultado =
          'R\$ $resultado';
    }

    return resultado;
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
  // CRIAR IMAGEM FINAL
  //
  // NÃO REMOVE FUNDO.
  // ============================================================

  Future<File?> _criarImagemFinal() async {
    if (_imagemRecortada == null) {
      return null;
    }

    try {
      final Uint8List bytes =
          await _imagemRecortada!
              .readAsBytes();

      final img.Image? foto =
          img.decodeImage(bytes);

      if (foto == null) {
        return _imagemRecortada;
      }

      final int largura =
          foto.width;

      final int alturaFoto =
          foto.height;

      final int alturaFaixa =
          (largura * 0.20).round();

      final int alturaTotal =
          alturaFoto + alturaFaixa;

      final img.Image resultado =
          img.Image(
        width: largura,
        height: alturaTotal,
      );

      img.fill(
        resultado,
        color: img.ColorRgb8(
          255,
          255,
          255,
        ),
      );

      img.compositeImage(
        resultado,
        foto,
        dstX: 0,
        dstY: 0,
      );

      final int verdeR = 5;
      final int verdeG = 102;
      final int verdeB = 72;

      img.fillRect(
        resultado,
        x1: 0,
        y1: alturaFoto,
        x2: largura - 1,
        y2: alturaTotal - 1,
        color: img.ColorRgb8(
          verdeR,
          verdeG,
          verdeB,
        ),
      );

      final List<int> png =
          img.encodePng(resultado);

      final String caminho =
          '${Directory.systemTemp.path}/divulgacao_final_${DateTime.now().millisecondsSinceEpoch}.png';

      final File arquivo =
          File(caminho);

      await arquivo.writeAsBytes(png);

      return arquivo;
    } catch (e) {
      return _imagemRecortada;
    }
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

    if (_imagemRecortada == null) {
      _mostrarMensagem(
        'Escolha o print do produto primeiro.',
      );
      return;
    }

    try {
      setState(() {
        _carregando = true;
      });

      final File? imagemFinal =
          await _criarImagemFinal();

      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      if (imagemFinal == null) {
        _mostrarMensagem(
          'Não foi possível preparar a imagem.',
        );
        return;
      }

      final String texto =
          _gerarTextoDivulgacao();

      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject:
              'Oferta Shopee - $_nomeProduto',
          files: [
            XFile(
              imagemFinal.path,
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Não foi possível compartilhar.\n\n$e',
      );
    }
  }

  // ============================================================
  // COMPARTILHAR SOMENTE TEXTO
  // ============================================================

  Future<void>
      _compartilharTexto() async {
    final String link =
        _obterLink();

    if (link.isEmpty) {
      _mostrarMensagem(
        'Digite o seu link de afiliado primeiro.',
      );
      return;
    }

    final String texto =
        _gerarTextoDivulgacao();

    await SharePlus.instance.share(
      ShareParams(
        text: texto,
      ),
    );
  }

  // ============================================================
  // LIMPAR
  // ============================================================

  void _limpar() {
    setState(() {
      _imagemOriginal = null;
      _imagemRecortada = null;

      _nomeProduto = '';
      _preco = '';
      _textoLido = '';

      _linkController.clear();
    });
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(
    String mensagem,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CARD DA IMAGEM
  // ============================================================

  Widget _cardImagemRecortada() {
    if (_imagemRecortada == null) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior:
          Clip.antiAlias,
      elevation: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            color:
                const Color(0xFFFFF0EB),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color:
                      Colors.deepOrange,
                ),
                SizedBox(width: 10),
                Text(
                  'FOTO RECORTADA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            width: double.infinity,
            child: Image.file(
              _imagemRecortada!,
              fit: BoxFit.contain,
            ),
          ),
        ],
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
              const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // LINK
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

              // BOTÃO ESCOLHER
              ElevatedButton.icon(
                onPressed:
                    _carregando
                        ? null
                        : _escolherPrint,
                icon: const Icon(
                  Icons.photo_library,
                ),
                label: const Text(
                  'ESCOLHER FOTO / PRINT DO PRODUTO',
                  style: TextStyle(
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

              // CARREGANDO
              if (_carregando)
                const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'Preparando o produto...',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // FOTO
              if (!_carregando)
                _cardImagemRecortada(),

              const SizedBox(
                height: 15,
              ),

              // INFORMAÇÕES
              if (!_carregando &&
                  (_nomeProduto
                          .isNotEmpty ||
                      _preco
                          .isNotEmpty))
                Card(
                  elevation: 2,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style:
                              TextStyle(
                            fontSize: 14,
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
                            fontSize: 19,
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
                            fontSize: 22,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                Colors
                                    .deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // TEXTO DETECTADO
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
                              .all(16),
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

              // COMPARTILHAR IMAGEM
              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed:
                      _carregando
                          ? null
                          : _compartilhar,
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

              // COMPARTILHAR TEXTO
              if (_nomeProduto
                      .isNotEmpty ||
                  _preco.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      _compartilharTexto,
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

              const SizedBox(
                height: 10,
              ),

              // LIMPAR
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

              const SizedBox(
                height: 20,
              ),

              const Text(
                'A imagem é apenas recortada. '
                'O aplicativo não remove o fundo do produto, '
                'evitando deformações e falhas no recorte.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
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

// ================================================================
// CLASSE PARA GUARDAR CADA LINHA DO OCR
//
// Isso permite ordenar o texto pela posição real na imagem,
// evitando que o começo de um título grande seja perdido.
// ================================================================

class _LinhaOCR {
  final String texto;
  final double topo;
  final double esquerda;

  _LinhaOCR({
    required this.texto,
    required this.topo,
    required this.esquerda,
  });
}

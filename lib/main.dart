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
  // NÃO REMOVE FUNDO.
  // SOMENTE RECORTA A REGIÃO DA FOTO.
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

      final int x =
          margemHorizontal;

      final int y =
          topo;

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

      final List<String> linhas = texto
          .split('\n')
          .map(
            (linha) => linha.trim(),
          )
          .where(
            (linha) => linha.isNotEmpty,
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
          preco = match.group(0) ?? '';
          indicePreco = i;

          if (linhas[i]
              .toLowerCase()
              .contains('r\$')) {
            break;
          }
        }
      }

      // ==========================================================
      // FUNÇÃO PARA IDENTIFICAR TEXTO QUE NÃO É PRODUTO
      // ==========================================================

      bool linhaEhLixo(String linha) {
        String t =
            linha.toLowerCase().trim();

        // Remove espaços duplicados.
        t = t.replaceAll(
          RegExp(r'\s+'),
          ' ',
        );

        // --------------------------------------------------------
        // COMISSÃO
        // --------------------------------------------------------

        if (t.contains('comissão extra') ||
            t.contains('comissao extra') ||
            t.contains('comissãoextra') ||
            t.contains('comissaoextra') ||
            t.contains('comissão') ||
            t.contains('comissao')) {
          return true;
        }

        // --------------------------------------------------------
        // PORCENTAGEM
        // --------------------------------------------------------

        if (RegExp(
          r'\d+[,.]?\d*\s*%',
        ).hasMatch(t)) {
          return true;
        }

        // --------------------------------------------------------
        // PREÇO
        // --------------------------------------------------------

        if (regexPreco.hasMatch(t)) {
          return true;
        }

        // --------------------------------------------------------
        // INFORMAÇÕES DE VENDA
        // --------------------------------------------------------

        final List<String> palavrasVenda = [
          'afiliados',
          'afiliado',
          'vendido',
          'vendidos',
          'vendas',
          'mil vendidos',
          'mil+ vendido',
          'mil+ vendidos',
          'avaliação',
          'avaliacao',
          'avaliações',
          'avaliacoes',
          'estrelas',
          'nota',
          'reviews',
          'review',
        ];

        for (final String palavra
            in palavrasVenda) {
          if (t.contains(palavra)) {
            return true;
          }
        }

        // --------------------------------------------------------
        // OUTROS TEXTOS DA SHOPEE
        // --------------------------------------------------------

        final List<String> ignorar = [
          'shopee',
          'comprar',
          'oferta',
          'promoção',
          'promocao',
          'frete grátis',
          'frete gratis',
          'cupom',
          'parcelado',
          'entrega',
          'compartilhar',
          'adicionar ao carrinho',
          'comprar agora',
          'aprenda com outros criadores',
          'aprenda com outros',
          'outros criadores',
          'compartilhe para ganhar',
          'compartilhe',
          'para ganhar',
          'ganhar',
          'chat',
          'favoritar',
          'favorito',
          'seguir',
          'seguindo',
          'ver mais',
          'ver tudo',
          'mais vendidos',
          'ofertas',
          'sem juros',
          'retirada',
          'entrega grátis',
          'entrega gratis',
        ];

        for (final String palavra
            in ignorar) {
          if (t.contains(palavra)) {
            return true;
          }
        }

        // --------------------------------------------------------
        // TEXTOS QUE COMEÇAM COM NÚMEROS
        // Normalmente são informações da Shopee.
        // --------------------------------------------------------

        if (RegExp(
          r'^\d+\s+',
        ).hasMatch(t)) {
          if (t.contains('dia') ||
              t.contains('dias') ||
              t.contains('hora') ||
              t.contains('horas') ||
              t.contains('parcela') ||
              t.contains('unidade') ||
              t.contains('vend')) {
            return true;
          }
        }

        // --------------------------------------------------------
        // LINHAS MUITO CURTAS
        // --------------------------------------------------------

        if (t.length < 5) {
          return true;
        }

        return false;
      }

      // ==========================================================
      // FUNÇÃO PARA SABER SE DEVEMOS PARAR O TÍTULO
      // ==========================================================

      bool ehFimDoTitulo(String linha) {
        final String t =
            linha.toLowerCase().trim();

        if (t.isEmpty) {
          return false;
        }

        // Informações de venda.
        if (t.contains('afiliado') ||
            t.contains('afiliados') ||
            t.contains('vendido') ||
            t.contains('vendidos') ||
            t.contains('avaliação') ||
            t.contains('avaliacao') ||
            t.contains('estrelas')) {
          return true;
        }

        // Área de outros criadores.
        if (t.contains('aprenda com') ||
            t.contains('outros criadores') ||
            t.contains('compartilhe para') ||
            t.contains('ganhar')) {
          return true;
        }

        // Botões da Shopee.
        if (t.contains('adicionar ao carrinho') ||
            t.contains('comprar agora') ||
            t.contains('frete') ||
            t.contains('cupom')) {
          return true;
        }

        // Outra porcentagem.
        if (RegExp(
          r'\d+[,.]?\d*\s*%',
        ).hasMatch(t)) {
          return true;
        }

        return false;
      }

      // ==========================================================
      // ENCONTRAR NOME DO PRODUTO
      //
      // IMPORTANTE:
      // Depois do preço ignoramos comissão.
      // Depois que encontramos o título,
      // paramos imediatamente quando aparecer
      // informação de venda ou outra área da Shopee.
      // ==========================================================

      if (indicePreco >= 0) {
        final List<String> partesNome = [];

        bool encontrouTitulo = false;

        for (
          int i = indicePreco + 1;
          i < linhas.length && i < indicePreco + 10;
          i++
        ) {
          final String linha =
              linhas[i].trim();

          if (linha.isEmpty) {
            continue;
          }

          // ------------------------------------------------------
          // Se chegou em informações abaixo do produto,
          // PARA completamente.
          // ------------------------------------------------------

          if (ehFimDoTitulo(linha)) {
            break;
          }

          // ------------------------------------------------------
          // Ignora comissão, porcentagem e lixo.
          // ------------------------------------------------------

          if (linhaEhLixo(linha)) {
            continue;
          }

          // ------------------------------------------------------
          // Não permite preços dentro do nome.
          // ------------------------------------------------------

          if (regexPreco.hasMatch(linha)) {
            continue;
          }

          // ------------------------------------------------------
          // Limite de tamanho.
          // ------------------------------------------------------

          if (linha.length > 180) {
            continue;
          }

          // ------------------------------------------------------
          // Adiciona somente linhas que parecem título.
          // ------------------------------------------------------

          partesNome.add(linha);

          encontrouTitulo = true;

          // ------------------------------------------------------
          // Normalmente o título da Shopee ocupa no máximo
          // 2 ou 3 linhas no OCR.
          //
          // Se já temos 3 linhas, não buscamos mais texto.
          // ------------------------------------------------------

          if (partesNome.length >= 3) {
            break;
          }

          // ------------------------------------------------------
          // Se a próxima linha claramente for lixo,
          // o próximo ciclo irá parar.
          // ------------------------------------------------------

          if (encontrouTitulo &&
              partesNome.length >= 2) {
            // Não paramos aqui porque alguns produtos
            // realmente possuem título em 3 linhas.
            continue;
          }
        }

        if (partesNome.isNotEmpty) {
          nome = partesNome.join(' ');
        }
      }

      // ==========================================================
      // SEGUNDA TENTATIVA
      //
      // Caso o OCR não encontre o preço corretamente.
      // ==========================================================

      if (nome.isEmpty) {
        final List<String> candidatos = [];

        for (final String linha in linhas) {
          if (linhaEhLixo(linha)) {
            continue;
          }

          if (ehFimDoTitulo(linha)) {
            continue;
          }

          if (regexPreco.hasMatch(linha)) {
            continue;
          }

          if (linha.length > 180) {
            continue;
          }

          candidatos.add(linha);
        }

        if (candidatos.isNotEmpty) {
          candidatos.sort(
            (a, b) =>
                b.length.compareTo(a.length),
          );

          nome = candidatos.first;
        }
      }

      // ==========================================================
      // LIMPAR NOME FINAL
      // ==========================================================

      nome =
          _limparNomeProduto(nome);

      if (!mounted) return;

      setState(() {
        _textoLido = texto;
        _nomeProduto = nome;
        _preco = _normalizarPreco(preco);
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
  // LIMPEZA FINAL DO NOME
  // ============================================================

  String _limparNomeProduto(String nome) {
    String resultado =
        nome.trim();

    // ------------------------------------------------------------
    // Remove comissão mesmo grudada no texto.
    // Exemplos:
    //
    // cOMISSÃOEXTRA Ventilador
    // COMISSÃO EXTRA Ventilador
    // comissaoextra Ventilador
    // ------------------------------------------------------------

    final List<RegExp> remover = [
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),

      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),

      RegExp(
        r'\bcomiss[aã]o\b',
        caseSensitive: false,
      ),

      RegExp(
        r'\bcomissao\b',
        caseSensitive: false,
      ),

      RegExp(
        r'\bextra\b',
        caseSensitive: false,
      ),

      RegExp(
        r'\b\d+[,.]?\d*\s*%',
        caseSensitive: false,
      ),
    ];

    for (final RegExp regex
        in remover) {
      resultado =
          resultado.replaceAll(
        regex,
        ' ',
      );
    }

    // ------------------------------------------------------------
    // Remove algumas palavras de interface caso o OCR tenha
    // conseguido colocá-las junto ao título.
    // ------------------------------------------------------------

    final List<String> frasesRemover = [
      'aprenda com outros criadores',
      'aprenda com outros',
      'outros criadores',
      'compartilhe para ganhar',
      'adicionar ao carrinho',
      'comprar agora',
    ];

    for (final String frase
        in frasesRemover) {
      resultado =
          resultado.replaceAll(
        RegExp(
          RegExp.escape(frase),
          caseSensitive: false,
        ),
        ' ',
      );
    }

    // ------------------------------------------------------------
    // Limpa caracteres estranhos no começo.
    // ------------------------------------------------------------

    resultado =
        resultado.replaceFirst(
      RegExp(r'^[\s\-:|•]+'),
      '',
    );

    // ------------------------------------------------------------
    // Remove espaços duplicados.
    // ------------------------------------------------------------

    resultado =
        resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return resultado.trim();
  }

  // ============================================================
  // NORMALIZAR PREÇO
  // ============================================================

  String _normalizarPreco(String preco) {
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

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
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
  // SOMENTE RECORTE.
  // NÃO REMOVE FUNDO.
  // ============================================================

  Future<File?> _criarImagemFinal() async {
    if (_imagemRecortada == null) {
      return null;
    }

    try {
      final Uint8List bytes =
          await _imagemRecortada!.readAsBytes();

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

  Future<void> _compartilharTexto() async {
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
        content:
            Text(mensagem),
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
                SizedBox(
                  width: 10,
                ),
                Text(
                  'FOTO RECORTADA',
                  style:
                      TextStyle(
                    fontSize: 17,
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
            width:
                double.infinity,
            child:
                Image.file(
              _imagemRecortada!,
              fit:
                  BoxFit.contain,
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
        title:
            const Text(
          'Divulgador Shopee',
          style:
              TextStyle(
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
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              // ==================================================
              // LINK
              // ==================================================

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

              // ==================================================
              // BOTÃO ESCOLHER
              // ==================================================

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

              // ==================================================
              // CARREGANDO
              // ==================================================

              if (_carregando)
                const Card(
                  child:
                      Padding(
                    padding:
                        EdgeInsets
                            .all(
                      20,
                    ),
                    child:
                        Column(
                      children: [
                        CircularProgressIndicator(),

                        SizedBox(
                          height: 12,
                        ),

                        Text(
                          'Preparando o produto...',
                          textAlign:
                              TextAlign
                                  .center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ==================================================
              // IMAGEM
              // ==================================================

              if (!_carregando)
                _cardImagemRecortada(),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // INFORMAÇÕES
              // ==================================================

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

              // ==================================================
              // TEXTO DETECTADO
              // ==================================================

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

              // ==================================================
              // COMPARTILHAR FOTO
              // ==================================================

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

              // ==================================================
              // COMPARTILHAR TEXTO
              // ==================================================

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
                ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // LIMPAR
              // ==================================================

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
                'A imagem é apenas recortada. '
                'O aplicativo não remove o fundo do produto, '
                'evitando deformações e falhas no recorte.',
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

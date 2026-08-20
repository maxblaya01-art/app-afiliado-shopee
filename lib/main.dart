import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

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
        scaffoldBackgroundColor: const Color(0xFFFFF8F5),
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

class _LinhaOCR {
  final String texto;
  final Rect caixa;

  _LinhaOCR({
    required this.texto,
    required this.caixa,
  });
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _linkController = TextEditingController();

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

      if (arquivo == null) return;

      setState(() {
        _imagemOriginal = File(arquivo.path);
        _imagemRecortada = null;
        _nomeProduto = '';
        _preco = '';
        _textoLido = '';
        _carregando = true;
      });

      await _lerTextoDaImagem(arquivo.path);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem('Erro ao abrir imagem.');
    }
  }

  // ============================================================
  // LIMPAR
  // ============================================================

  void _limparTudo() {
    setState(() {
      _imagemOriginal = null;
      _imagemRecortada = null;
      _nomeProduto = '';
      _preco = '';
      _textoLido = '';
      _linkController.clear();
      _carregando = false;
    });

    _mostrarMensagem('Tudo limpo.');
  }

  // ============================================================
  // LIMPEZA DE TEXTO DO OCR
  // ============================================================

  String _limparLinha(String texto) {
    String t = texto.trim();

    // ----------------------------------------------------------
    // REMOVE "COMISSÃO EXTRA" EM DIVERSOS FORMATOS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'comiss[aã]o\s*e\s*x\s*t\s*r\s*a',
        caseSensitive: false,
      ),
      '',
    );

    t = t.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      '',
    );

    t = t.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE PERCENTUAIS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE LINKS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(
        r'https?:\/\/\S+',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE PONTOS EXCESSIVOS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(r'\.{2,}|…+'),
      '',
    );

    // ----------------------------------------------------------
    // CORRIGE ESPAÇOS
    // ----------------------------------------------------------

    t = t.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return t.trim();
  }

  // ============================================================
  // IDENTIFICA TEXTOS DA INTERFACE DA SHOPEE
  // ============================================================

  bool _ehInterface(String texto) {
    final t = texto.toLowerCase().trim();

    final termos = [
      'comissão extra',
      'comissao extra',
      'comissãoextra',
      'comissaoextra',

      'comissão',
      'comissao',

      'afiliados',
      'afiliado',

      'promoveram',

      'aprenda com outros criadores',

      'compartilhe',
      'compartilhar',

      'chat',

      'favorito',
      'favoritar',

      'vendido',
      'vendidos',

      'avaliações',
      'avaliacoes',

      'estrelas',

      'oferta',

      'cupom',

      'frete grátis',
      'frete gratis',

      'comprar agora',

      'adicionar ao carrinho',

      'entrega',

      'parcelado',

      'visitar',

      'loja',

      'mais vendidos',

      'android 13.0',

      'auto-focus',
      'autofocus',

      'wifi 6',

      'max support',
    ];

    for (final termo in termos) {
      if (t.contains(termo)) {
        return true;
      }
    }

    // Horário do celular
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t)) {
      return true;
    }

    // Linhas contendo somente números, porcentagens etc.
    if (RegExp(r'^[\d\s.,/%]+$').hasMatch(t)) {
      return true;
    }

    return false;
  }

  // ============================================================
  // PREÇO
  // ============================================================

  String _normalizarPreco(String preco) {
    String p = preco.trim();

    if (p.isEmpty) {
      return '';
    }

    p = p.replaceAll(
      RegExp(r'\s+'),
      '',
    );

    if (!p.toLowerCase().startsWith('r\$')) {
      p = 'R\$$p';
    }

    return p;
  }

  // ============================================================
  // AJUSTAR NOME DO PRODUTO
  // ============================================================

  String _ajustarNomeProduto(String nome) {
    String n = nome;

    // Limpeza geral
    n = _limparLinha(n);

    // ----------------------------------------------------------
    // PROTEÇÃO EXTRA CONTRA COMISSÃO EXTRA
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(
        r'comiss[aã]o\s*e\s*x\s*t\s*r\s*a',
        caseSensitive: false,
      ),
      '',
    );

    n = n.replaceAll(
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      '',
    );

    n = n.replaceAll(
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE PREÇO CASO TENHA ENTRADO NO NOME
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2}',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE PERCENTUAIS
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(
        r'\b\d{1,3}(?:[.,]\d+)?\s*%',
        caseSensitive: false,
      ),
      '',
    );

    // ----------------------------------------------------------
    // REMOVE CARACTERES DESNECESSÁRIOS DO COMEÇO
    // ----------------------------------------------------------

    n = n.replaceFirst(
      RegExp(r'^[\s\-:|]+'),
      '',
    );

    // ----------------------------------------------------------
    // CORRIGE ESPAÇOS
    // ----------------------------------------------------------

    n = n.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    n = n.trim();

    // ----------------------------------------------------------
    // LIMITA TAMANHO DO NOME
    // ----------------------------------------------------------

    if (n.length > 170) {
      n = n.substring(0, 170);

      final pos = n.lastIndexOf(' ');

      if (pos > 0) {
        n = n.substring(0, pos);
      }
    }

    return n.trim();
  }

  // ============================================================
  // RECORTAR FOTO DO PRODUTO
  // ============================================================

  Future<File?> _recortarAreaDoProduto(String caminho) async {
    try {
      final arquivo = File(caminho);

      final Uint8List bytes =
          await arquivo.readAsBytes();

      final img.Image? original =
          img.decodeImage(bytes);

      if (original == null) {
        return null;
      }

      final largura = original.width;
      final altura = original.height;

      // Remove pequena parte superior do print
      final topo =
          (altura * 0.045).round();

      // Área principal da foto do produto
      final fundo =
          (altura * 0.435).round();

      // Margem lateral
      final margem =
          (largura * 0.025).round();

      final larguraRecorte =
          largura - (margem * 2);

      final alturaRecorte =
          fundo - topo;

      if (larguraRecorte <= 0 ||
          alturaRecorte <= 0) {
        return null;
      }

      final recorte = img.copyCrop(
        original,
        x: margem,
        y: topo,
        width: larguraRecorte,
        height: alturaRecorte,
      );

      final novo =
          '${arquivo.parent.path}/produto_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final resultado = File(novo);

      await resultado.writeAsBytes(
        Uint8List.fromList(
          img.encodeJpg(
            recorte,
            quality: 95,
          ),
        ),
      );

      return resultado;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // LER TEXTO DA IMAGEM
  // ============================================================

  Future<void> _lerTextoDaImagem(
    String caminho,
  ) async {
    final reconhecedor =
        TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final imagem =
          InputImage.fromFilePath(caminho);

      final resultado =
          await reconhecedor.processImage(
        imagem,
      );

      final linhas = <_LinhaOCR>[];

      // --------------------------------------------------------
      // ORGANIZA TODAS AS LINHAS DO OCR
      // --------------------------------------------------------

      for (final bloco in resultado.blocks) {
        for (final linha in bloco.lines) {
          if (linha.text.trim().isNotEmpty) {
            linhas.add(
              _LinhaOCR(
                texto: linha.text.trim(),
                caixa: linha.boundingBox,
              ),
            );
          }
        }
      }

      // --------------------------------------------------------
      // ORDENA DE CIMA PARA BAIXO
      // --------------------------------------------------------

      linhas.sort(
        (a, b) {
          final y =
              a.caixa.top.compareTo(
            b.caixa.top,
          );

          if (y != 0) {
            return y;
          }

          return a.caixa.left.compareTo(
            b.caixa.left,
          );
        },
      );

      // ========================================================
      // REGEX CORRETA DO PREÇO
      // ========================================================

      final regexPreco = RegExp(
        r'(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2}',
        caseSensitive: false,
      );

      String preco = '';
      double precoBottom = 0;

      // ========================================================
      // PROCURAR PREÇO
      // ========================================================

      for (final linha in linhas) {
        final match =
            regexPreco.firstMatch(
          linha.texto,
        );

        if (match != null) {
          final valor =
              match.group(0) ?? '';

          if (valor.isNotEmpty) {
            preco =
                _normalizarPreco(valor);

            precoBottom =
                linha.caixa.bottom;

            break;
          }
        }
      }

      // ========================================================
      // PROCURAR NOME
      // ========================================================

      final partes = <String>[];

      if (precoBottom > 0) {
        double ultimoBottom =
            precoBottom;

        for (final linha in linhas) {
          // Ignora textos acima do preço
          if (linha.caixa.top <
              precoBottom - 2) {
            continue;
          }

          // Se houver um espaço muito grande,
          // provavelmente começou outra área
          if (linha.caixa.top -
                      ultimoBottom >
                  85 &&
              partes.isNotEmpty) {
            break;
          }

          final original =
              linha.texto;

          // ----------------------------------------------------
          // PRIMEIRA FILTRAGEM
          // ----------------------------------------------------

          if (_ehInterface(original)) {
            if (partes.isNotEmpty) {
              break;
            }

            continue;
          }

          final limpa =
              _limparLinha(original);

          if (limpa.isEmpty) {
            continue;
          }

          // ----------------------------------------------------
          // SEGUNDA FILTRAGEM
          // ----------------------------------------------------

          if (_ehInterface(limpa)) {
            if (partes.isNotEmpty) {
              break;
            }

            continue;
          }

          // ----------------------------------------------------
          // NÃO DEIXA PREÇO ENTRAR NO NOME
          // ----------------------------------------------------

          if (regexPreco.hasMatch(limpa)) {
            continue;
          }

          // ----------------------------------------------------
          // IGNORA TEXTOS MUITO PEQUENOS
          // ----------------------------------------------------

          if (limpa.length < 4) {
            continue;
          }

          partes.add(limpa);

          ultimoBottom =
              linha.caixa.bottom;

          // Normalmente o título fica
          // em poucas linhas
          if (partes.length >= 5) {
            break;
          }
        }
      }

      // ========================================================
      // FALLBACK
      // ========================================================

      if (partes.isEmpty) {
        final candidatos = <String>[];

        for (final linha in linhas) {
          String texto =
              _limparLinha(
            linha.texto,
          );

          if (texto.isEmpty) {
            continue;
          }

          if (_ehInterface(texto)) {
            continue;
          }

          if (regexPreco.hasMatch(texto)) {
            continue;
          }

          if (texto.length >= 8) {
            candidatos.add(texto);
          }
        }

        // Pega até 3 linhas úteis
        for (final candidato
            in candidatos.take(3)) {
          partes.add(candidato);
        }
      }

      // ========================================================
      // MONTA NOME
      // ========================================================

      String nome =
          _ajustarNomeProduto(
        partes.join(' '),
      );

      // ========================================================
      // SEGUNDA PROTEÇÃO
      // ========================================================

      nome = _ajustarNomeProduto(nome);

      // ========================================================
      // RECORTAR FOTO
      // ========================================================

      final foto =
          await _recortarAreaDoProduto(
        caminho,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // ATUALIZAR TELA
      // ========================================================

      setState(() {
        _textoLido =
            resultado.text;

        _nomeProduto =
            nome;

        _preco =
            preco;

        _imagemRecortada =
            foto;

        _carregando =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem(
        'Erro ao reconhecer o print.',
      );
    } finally {
      await reconhecedor.close();
    }
  }

  // ============================================================
  // OBTER LINK
  // ============================================================

  String _obterLink() {
    String link =
        _linkController.text.trim();

    if (link.isEmpty) {
      return '';
    }

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link = 'https://$link';
    }

    return link;
  }

  // ============================================================
  // TEXTO DA DIVULGAÇÃO
  // ============================================================

  String _gerarTextoDivulgacao() {
    return '''
🛍️ ${_nomeProduto.isEmpty ? 'Produto Shopee' : _nomeProduto}

🔥 OFERTA NA SHOPEE 🔥

💰 ${_preco.isEmpty ? 'Confira o preço' : _preco}

👇 Confira aqui:
${_obterLink()}

🛒 Aproveite a oferta!
'''.trim();
  }

  // ============================================================
  // COMPARTILHAR FOTO
  // ============================================================

  Future<void> _compartilharFoto() async {
    if (_obterLink().isEmpty) {
      _mostrarMensagem(
        'Digite o link de afiliado.',
      );
      return;
    }

    if (_imagemOriginal == null) {
      _mostrarMensagem(
        'Escolha um print.',
      );
      return;
    }

    final arquivo =
        _imagemRecortada ??
            _imagemOriginal!;

    await SharePlus.instance.share(
      ShareParams(
        text:
            _gerarTextoDivulgacao(),
        files: [
          XFile(arquivo.path),
        ],
      ),
    );
  }

  // ============================================================
  // COMPARTILHAR SOMENTE TEXTO
  // ============================================================

  Future<void> _compartilharTexto() async {
    if (_obterLink().isEmpty) {
      _mostrarMensagem(
        'Digite o link de afiliado.',
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
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(
    String texto,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(texto),
      ),
    );
  }

  // ============================================================
  // CAMPO DO LINK
  // ============================================================

  Widget _campoLink() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: TextField(
        controller:
            _linkController,
        decoration:
            InputDecoration(
          hintText:
              'Link do produto / link de afiliado',
          prefixIcon:
              const Icon(Icons.link),
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOTO
  // ============================================================

  Widget _foto() {
    if (_imagemRecortada == null) {
      return const SizedBox();
    }

    return Container(
      margin:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Image.file(
          _imagemRecortada!,
          width:
              double.infinity,
          fit:
              BoxFit.contain,
        ),
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES
  // ============================================================

  Widget _informacoes() {
    return Container(
      margin:
          const EdgeInsets.all(16),
      padding:
          const EdgeInsets.all(28),
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF1EC),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMAÇÕES ENCONTRADAS',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 26,
          ),

          Text(
            'NOME DO PRODUTO',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            _nomeProduto.isEmpty
                ? 'Produto não identificado'
                : _nomeProduto,
            style:
                const TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _preco.isEmpty
                ? 'Não identificado'
                : _preco,
            style:
                const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TELA PRINCIPAL
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final temImagem =
        _imagemOriginal != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.deepOrange,
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontSize: 30,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body:
          SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 30,
            ),

            _campoLink(),

            const SizedBox(
              height: 24,
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                height: 120,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _carregando
                          ? null
                          : _escolherPrint,
                  icon:
                      const Icon(
                    Icons.image_outlined,
                    size: 32,
                  ),
                  label:
                      const Text(
                    'ESCOLHER FOTO / PRINT DO PRODUTO',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // --------------------------------------------------
            // CARREGANDO
            // --------------------------------------------------

            if (_carregando)
              const Padding(
                padding:
                    EdgeInsets.all(35),
                child:
                    CircularProgressIndicator(),
              ),

            // --------------------------------------------------
            // FOTO
            // --------------------------------------------------

            if (!_carregando &&
                temImagem)
              _foto(),

            // --------------------------------------------------
            // INFORMAÇÕES
            // --------------------------------------------------

            if (!_carregando &&
                temImagem)
              _informacoes(),

            // --------------------------------------------------
            // LIMPAR
            // --------------------------------------------------

            if (!_carregando &&
                temImagem)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _limparTudo,
                    icon:
                        const Icon(
                      Icons.delete_outline,
                    ),
                    label:
                        const Text(
                      'LIMPAR TUDO',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // --------------------------------------------------
            // COMPARTILHAMENTO
            // --------------------------------------------------

            if (!_carregando &&
                temImagem)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  30,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width:
                          double.infinity,
                      height: 58,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _compartilharFoto,
                        icon:
                            const Icon(
                          Icons.image,
                        ),
                        label:
                            const Text(
                          'COMPARTILHAR FOTO + DIVULGAÇÃO',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.deepOrange,
                          foregroundColor:
                              Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _compartilharTexto,
                        icon:
                            const Icon(
                          Icons.share,
                        ),
                        label:
                            const Text(
                          'COMPARTILHAR SOMENTE TEXTO',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // --------------------------------------------------
            // TEXTO INICIAL
            // --------------------------------------------------

            if (!temImagem &&
                !_carregando)
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  35,
                  60,
                  35,
                  20,
                ),
                child:
                    Text(
                  'O aplicativo identifica automaticamente o preço e o título do produto, recorta somente a área da foto e prepara a divulgação.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color:
                        Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

      final List<String> linhas = texto
          .split('\n')
          .map((linha) => linha.trim())
          .where((linha) => linha.isNotEmpty)
          .toList();

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
      // LIMPEZA DE UMA LINHA
      // ==========================================================

      String limparLinha(String linha) {
        String resultado = linha.trim();

        // --------------------------------------------------------
        // COMISSÃO EXTRA
        //
        // Remove vários erros comuns do OCR:
        //
        // COMISSÃO EXTRA
        // COMISSAO EXTRA
        // COMISSÃOEXTRA
        // COMISSAOEXTRA
        // COMISSÃO EX TRA
        // COMISSAO EX TRA
        // COMISSÃOEX TRA
        // --------------------------------------------------------

        resultado = resultado.replaceAll(
          RegExp(
            r'comiss[aã]o\s*e\s*x\s*t\s*r\s*a',
            caseSensitive: false,
          ),
          ' ',
        );

        resultado = resultado.replaceAll(
          RegExp(
            r'comiss[aã]o\s*extra',
            caseSensitive: false,
          ),
          ' ',
        );

        resultado = resultado.replaceAll(
          RegExp(
            r'comiss[aã]oextra',
            caseSensitive: false,
          ),
          ' ',
        );

        resultado = resultado.replaceAll(
          RegExp(
            r'comiss[aã]o\s*ex\s*tra',
            caseSensitive: false,
          ),
          ' ',
        );

        // Caso o OCR misture letras maiúsculas/minúsculas.
        resultado = resultado.replaceAll(
          RegExp(
            r'c\s*o\s*m\s*i\s*s\s*s\s*[aã]\s*o\s*e\s*x\s*t\s*r\s*a',
            caseSensitive: false,
          ),
          ' ',
        );

        // --------------------------------------------------------
        // PERCENTUAL
        // --------------------------------------------------------

        resultado = resultado.replaceAll(
          RegExp(
            r'\d+[,.]?\d*\s*%',
            caseSensitive: false,
          ),
          ' ',
        );

        // --------------------------------------------------------
        // PREÇO
        // --------------------------------------------------------

        resultado = resultado.replaceAll(
          RegExp(
            r'R\$\s*\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
            caseSensitive: false,
          ),
          ' ',
        );

        // --------------------------------------------------------
        // FRASES DA INTERFACE
        // --------------------------------------------------------

        final List<RegExp> frasesLixo = [
          RegExp(
            r'mais vendidos.*',
            caseSensitive: false,
          ),
          RegExp(
            r'no\.\s*\d+',
            caseSensitive: false,
          ),
          RegExp(
            r'\d+\s*afiliados promoveram.*',
            caseSensitive: false,
          ),
          RegExp(
            r'afiliados promoveram.*',
            caseSensitive: false,
          ),
          RegExp(
            r'aprenda com outros criadores.*',
            caseSensitive: false,
          ),
          RegExp(
            r'compartilhe para ganhar.*',
            caseSensitive: false,
          ),
          RegExp(
            r'vendido.*',
            caseSensitive: false,
          ),
        ];

        for (final RegExp regex in frasesLixo) {
          resultado =
              resultado.replaceAll(regex, ' ');
        }

        // --------------------------------------------------------
        // LIMPEZA FINAL DOS ESPAÇOS
        // --------------------------------------------------------

        resultado =
            resultado.replaceAll(RegExp(r'\s+'), ' ');

        resultado = resultado.trim();

        return resultado;
      }

      // ==========================================================
      // VERIFICAR SE É LINHA DE INTERFACE
      // ==========================================================

      bool linhaEhLixo(String linha) {
        final String t =
            linha.toLowerCase().trim();

        if (t.isEmpty) {
          return true;
        }

        final List<String> palavras = [
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
          'vendido',
          'parcelado',
          'entrega',
          'compartilhar',
          'adicionar ao carrinho',
          'comprar agora',
          'comissão extra',
          'comissao extra',
          'comissãoextra',
          'comissaoextra',
          'comissão',
          'comissao',
          'aprenda com outros criadores',
          'compartilhe para ganhar',
          'chat',
          'favoritar',
          'mais vendidos',
          'afiliados promoveram',
          'mil+ vendido',
        ];

        for (final String palavra in palavras) {
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

      // ==========================================================
      // MONTAR CANDIDATOS DO NOME
      // ==========================================================

      final List<String> candidatos = [];

      if (indicePreco >= 0) {
        // Procuramos somente algumas linhas depois do preço.
        //
        // Isso evita pegar textos muito abaixo:
        // "Aprenda com outros criadores",
        // "Afiliados promoveram",
        // etc.
        for (
          int i = indicePreco + 1;
          i < linhas.length &&
              i <= indicePreco + 6;
          i++
        ) {
          String linha = linhas[i];

          linha = limparLinha(linha);

          if (linha.isEmpty) {
            continue;
          }

          if (linhaEhLixo(linha)) {
            continue;
          }

          if (regexPreco.hasMatch(linha)) {
            continue;
          }

          // Percentual isolado não entra.
          if (RegExp(
            r'^\s*\d+[,.]?\d*\s*%\s*$',
          ).hasMatch(linha)) {
            continue;
          }

          // Evita textos enormes da interface.
          if (linha.length > 150) {
            continue;
          }

          candidatos.add(linha);
        }
      }

      // ==========================================================
      // SEGUNDA FORMA DE LOCALIZAR
      //
      // Caso o OCR tenha colocado o título em ordem estranha,
      // procuramos linhas que realmente parecem título.
      // ==========================================================

      if (candidatos.isEmpty) {
        for (final String linhaOriginal in linhas) {
          String linha =
              limparLinha(linhaOriginal);

          if (linha.isEmpty) {
            continue;
          }

          if (linhaEhLixo(linha)) {
            continue;
          }

          if (regexPreco.hasMatch(linha)) {
            continue;
          }

          // Não aceitar horário.
          if (RegExp(
            r'^\d{1,2}:\d{2}$',
          ).hasMatch(linha)) {
            continue;
          }

          // Não aceitar apenas números.
          if (RegExp(
            r'^\d+$',
          ).hasMatch(linha)) {
            continue;
          }

          if (linha.length < 5) {
            continue;
          }

          if (linha.length > 150) {
            continue;
          }

          candidatos.add(linha);
        }
      }

      // ==========================================================
      // LIMPAR CANDIDATOS
      // ==========================================================

      final List<String> candidatosLimpos = [];

      for (String candidato in candidatos) {
        candidato = _limparNomeProduto(candidato);

        if (candidato.isEmpty) {
          continue;
        }

        if (candidato.length < 5) {
          continue;
        }

        candidatosLimpos.add(candidato);
      }

      // ==========================================================
      // MONTAR NOME
      // ==========================================================

      String nome = '';

      if (candidatosLimpos.isNotEmpty) {
        final List<String> partes = [];

        for (final String candidato
            in candidatosLimpos) {
          // Não repetir exatamente a mesma linha.
          if (partes.any(
            (p) =>
                p.toLowerCase() ==
                candidato.toLowerCase(),
          )) {
            continue;
          }

          partes.add(candidato);

          // Títulos muito grandes podem ocupar até 3 linhas.
          if (partes.length >= 3) {
            break;
          }
        }

        nome = partes.join(' ');
      }

      // ==========================================================
      // LIMPEZA FINAL DO NOME
      // ==========================================================

      nome = _limparNomeProduto(nome);

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
  // LIMPAR NOME DO PRODUTO
  // ============================================================

  String _limparNomeProduto(String nome) {
    String resultado = nome.trim();

    // ------------------------------------------------------------
    // REMOVE COMISSÃO EXTRA EM QUALQUER FORMATO
    // ------------------------------------------------------------

    final List<RegExp> removerComissao = [
      RegExp(
        r'comiss[aã]o\s*e\s*x\s*t\s*r\s*a',
        caseSensitive: false,
      ),
      RegExp(
        r'comiss[aã]o\s*extra',
        caseSensitive: false,
      ),
      RegExp(
        r'comiss[aã]oextra',
        caseSensitive: false,
      ),
      RegExp(
        r'comiss[aã]o\s*ex\s*tra',
        caseSensitive: false,
      ),
      RegExp(
        r'c\s*o\s*m\s*i\s*s\s*s\s*[aã]\s*o\s*e\s*x\s*t\s*r\s*a',
        caseSensitive: false,
      ),
    ];

    for (final RegExp regex in removerComissao) {
      resultado =
          resultado.replaceAll(regex, ' ');
    }

    // ------------------------------------------------------------
    // REMOVE PERCENTUAL
    // ------------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d+[,.]?\d*\s*%',
        caseSensitive: false,
      ),
      ' ',
    );

    // ------------------------------------------------------------
    // REMOVE ALGUNS ELEMENTOS DA INTERFACE
    // ------------------------------------------------------------

    final List<RegExp> removerInterface = [
      RegExp(
        r'mais vendidos.*',
        caseSensitive: false,
      ),
      RegExp(
        r'afiliados promoveram.*',
        caseSensitive: false,
      ),
      RegExp(
        r'aprenda com outros criadores.*',
        caseSensitive: false,
      ),
      RegExp(
        r'compartilhe para ganhar.*',
        caseSensitive: false,
      ),
    ];

    for (final RegExp regex
        in removerInterface) {
      resultado =
          resultado.replaceAll(regex, ' ');
    }

    // ------------------------------------------------------------
    // REMOVE PREÇO SE ACABAR NO NOME
    // ------------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'R\$\s*\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})',
        caseSensitive: false,
      ),
      ' ',
    );

    // ------------------------------------------------------------
    // REMOVE HORÁRIO
    // ------------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d{1,2}:\d{2}\b',
      ),
      ' ',
    );

    // ------------------------------------------------------------
    // REMOVE NÚMERO DE FOTOS
    // Ex.: 1/8, 1/9, 1/15
    // ------------------------------------------------------------

    resultado = resultado.replaceAll(
      RegExp(
        r'\b\d+\s*/\s*\d+\b',
      ),
      ' ',
    );

    // ------------------------------------------------------------
    // CORRIGE ESPAÇOS
    // ------------------------------------------------------------

    resultado =
        resultado.replaceAll(RegExp(r'\s+'), ' ');

    resultado = resultado.trim();

    // ------------------------------------------------------------
    // REMOVE PALAVRAS REPETIDAS NO FINAL
    // Exemplo:
    //
    // "... Diamante Pendente"
    //
    // quando Pendente já apareceu no título.
    // ------------------------------------------------------------

    final List<String> palavras =
        resultado.split(' ');

    if (palavras.length >= 4) {
      final List<String> novas = [];

      for (final palavra in palavras) {
        final String atual =
            palavra
                .replaceAll(
                  RegExp(r'[^\p{L}\p{N}]',
                      unicode: true),
                  '',
                )
                .toLowerCase();

        if (atual.isEmpty) {
          novas.add(palavra);
          continue;
        }

        // Se a mesma palavra apareceu recentemente,
        // não adiciona novamente.
        bool repetida = false;

        final int inicio =
            novas.length > 8
                ? novas.length - 8
                : 0;

        for (int i = inicio;
            i < novas.length;
            i++) {
          final String anterior =
              novas[i]
                  .replaceAll(
                    RegExp(
                      r'[^\p{L}\p{N}]',
                      unicode: true,
                    ),
                    '',
                  )
                  .toLowerCase();

          if (anterior == atual) {
            repetida = true;
            break;
          }
        }

        if (!repetida) {
          novas.add(palavra);
        }
      }

      resultado = novas.join(' ');
    }

    // ------------------------------------------------------------
    // LIMPEZA FINAL
    // ------------------------------------------------------------

    resultado =
        resultado.replaceAll(RegExp(r'\s+'), ' ');

    return resultado.trim();
  }

  // ============================================================
  // NORMALIZAR PREÇO
  // ============================================================

  String _normalizarPreco(String preco) {
    String resultado = preco.trim();

    if (resultado.isEmpty) {
      return '';
    }

    if (!resultado
        .toLowerCase()
        .contains('r\$')) {
      resultado = 'R\$ $resultado';
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
      link = 'https://$link';
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

      final int largura = foto.width;
      final int alturaFoto = foto.height;

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

      img.fillRect(
        resultado,
        x1: 0,
        y1: alturaFoto,
        x2: largura - 1,
        y2: alturaTotal - 1,
        color: img.ColorRgb8(
          5,
          102,
          72,
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
            XFile(imagemFinal.path),
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

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
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
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFFFF0EB),
            child: const Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.deepOrange,
                ),
                SizedBox(width: 10),
                Text(
                  'FOTO RECORTADA',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF8F5),

      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText:
                      'Link do produto / link de afiliado',
                  hintText:
                      'Cole seu link aqui',
                  prefixIcon:
                      const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style:
                    ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (_carregando)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Preparando o produto...',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_carregando)
                _cardImagemRecortada(),

              const SizedBox(height: 15),

              if (!_carregando &&
                  (_nomeProduto.isNotEmpty ||
                      _preco.isNotEmpty))
                Card(
                  elevation: 2,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INFORMAÇÕES ENCONTRADAS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          'NOME DO PRODUTO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _nomeProduto.isEmpty
                              ? 'Não identificado'
                              : _nomeProduto,
                          style:
                              const TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'PREÇO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _preco.isEmpty
                              ? 'Não identificado'
                              : _preco,
                          style:
                              const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_textoLido.isNotEmpty)
                ExpansionTile(
                  title: const Text(
                    'Ver texto detectado no print',
                  ),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: SelectableText(
                        _textoLido,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              if (_nomeProduto.isNotEmpty ||
                  _preco.isNotEmpty)
                ElevatedButton.icon(
                  onPressed:
                      _carregando
                          ? null
                          : _compartilhar,
                  icon:
                      const Icon(Icons.image),
                  label: const Text(
                    'COMPARTILHAR FOTO + DIVULGAÇÃO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.deepOrange,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              if (_nomeProduto.isNotEmpty ||
                  _preco.isNotEmpty)
                OutlinedButton.icon(
                  onPressed:
                      _compartilharTexto,
                  icon: const Icon(
                    Icons.text_fields,
                  ),
                  label: const Text(
                    'COMPARTILHAR SOMENTE TEXTO',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              if (_imagemOriginal != null)
                OutlinedButton.icon(
                  onPressed: _limpar,
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label: const Text(
                    'LIMPAR',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              const Text(
                'A imagem é apenas recortada. '
                'O aplicativo não remove o fundo do produto, '
                'evitando deformações e falhas no recorte.',
                textAlign: TextAlign.center,
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


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
      setState(() => _carregando = false);
      _mostrarMensagem('Erro ao abrir imagem.');
    }
  }

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

  String _limparLinha(String texto) {
    String t = texto.trim();

    t = t.replaceAll(
      RegExp(r'comiss[aã]o\s*ex\s*tra', caseSensitive: false),
      '',
    );

    t = t.replaceAll(
      RegExp(r'comiss[aã]oextra', caseSensitive: false),
      '',
    );

    t = t.replaceAll(
      RegExp(r'\b\d{1,3}(?:[.,]\d+)?\s*%', caseSensitive: false),
      '',
    );

    t = t.replaceAll(
      RegExp(r'\.{2,}|…+'),
      '',
    );

    t = t.replaceAll(
      RegExp(r'https?:\/\/\S+', caseSensitive: false),
      '',
    );

    t = t.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return t.trim();
  }

  bool _ehInterface(String texto) {
    final t = texto.toLowerCase();

    final termos = [
      'comissão',
      'comissao',
      'extra',
      'afiliados',
      'afiliado',
      'promoveram',
      'aprenda com outros criadores',
      'compartilhe',
      'compartilhar',
      'chat',
      'favorito',
      'vendido',
      'vendidos',
      'avaliações',
      'avaliacoes',
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
      if (t.contains(termo)) return true;
    }

    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t)) return true;

    if (RegExp(r'^[\d\s.,/%]+$').hasMatch(t)) return true;

    return false;
  }

  String _normalizarPreco(String preco) {
    String p = preco.trim();

    if (p.isEmpty) return '';

    p = p.replaceAll(' ', '');

    if (!p.toLowerCase().startsWith('r\$')) {
      p = 'R\$$p';
    }

    return p;
  }

  String _ajustarNomeProduto(String nome) {
    String n = _limparLinha(nome);

    n = n.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (n.length > 170) {
      n = n.substring(0, 170);
      final pos = n.lastIndexOf(' ');
      if (pos > 0) n = n.substring(0, pos);
    }

    return n.trim();
  }

  Future<File?> _recortarAreaDoProduto(String caminho) async {
    try {
      final arquivo = File(caminho);
      final Uint8List bytes = await arquivo.readAsBytes();

      final img.Image? original = img.decodeImage(bytes);
      if (original == null) return null;

      final largura = original.width;
      final altura = original.height;

      final topo = (altura * 0.045).round();
      final fundo = (altura * 0.435).round();

      final margem = (largura * 0.025).round();

      final recorte = img.copyCrop(
        original,
        x: margem,
        y: topo,
        width: largura - margem * 2,
        height: fundo - topo,
      );

      final novo =
          '${arquivo.parent.path}/produto_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final resultado = File(novo);

      await resultado.writeAsBytes(
        Uint8List.fromList(
          img.encodeJpg(recorte, quality: 95),
        ),
      );

      return resultado;
    } catch (_) {
      return null;
    }
  }

  Future<void> _lerTextoDaImagem(String caminho) async {
    final reconhecedor =
        TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final imagem = InputImage.fromFilePath(caminho);

      final resultado =
          await reconhecedor.processImage(imagem);

      final linhas = <_LinhaOCR>[];

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

      linhas.sort((a, b) {
        final y = a.caixa.top.compareTo(b.caixa.top);
        if (y != 0) return y;
        return a.caixa.left.compareTo(b.caixa.left);
      });

      final regexPreco = RegExp(
        r'(?:R\$\\s*)?\\d{1,3}(?:[.]\\d{3})*,\\d{2}',
        caseSensitive: false,
      );

      String preco = '';
      double precoBottom = 0;

      for (final linha in linhas) {
        final match = regexPreco.firstMatch(linha.texto);

        if (match != null) {
          final valor = match.group(0) ?? '';

          if (valor.isNotEmpty) {
            preco = _normalizarPreco(valor);
            precoBottom = linha.caixa.bottom;
            break;
          }
        }
      }

      final partes = <String>[];

      if (precoBottom > 0) {
        double ultimoBottom = precoBottom;

        for (final linha in linhas) {
          if (linha.caixa.top < precoBottom - 2) continue;

          if (linha.caixa.top - ultimoBottom > 85 && partes.isNotEmpty) {
            break;
          }

          final original = linha.texto;

          if (_ehInterface(original)) {
            if (partes.isNotEmpty) break;
            continue;
          }

          final limpa = _limparLinha(original);

          if (limpa.isEmpty) continue;

          if (_ehInterface(limpa)) {
            if (partes.isNotEmpty) break;
            continue;
          }

          if (regexPreco.hasMatch(limpa)) continue;

          if (limpa.length < 4) continue;

          partes.add(limpa);
          ultimoBottom = linha.caixa.bottom;

          if (partes.length >= 4) break;
        }
      }

      if (partes.isEmpty) {
        for (final linha in linhas) {
          final texto = _limparLinha(linha.texto);

          if (texto.isEmpty) continue;
          if (_ehInterface(texto)) continue;
          if (regexPreco.hasMatch(texto)) continue;

          if (texto.length >= 8) {
            partes.add(texto);
          }

          if (partes.length >= 2) break;
        }
      }

      String nome = _ajustarNomeProduto(
        partes.join(' '),
      );

      final foto = await _recortarAreaDoProduto(caminho);

      if (!mounted) return;

      setState(() {
        _textoLido = resultado.text;
        _nomeProduto = nome;
        _preco = preco;
        _imagemRecortada = foto;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      _mostrarMensagem('Erro ao reconhecer o print.');
    } finally {
      await reconhecedor.close();
    }
  }

  String _obterLink() {
    String link = _linkController.text.trim();

    if (link.isEmpty) return '';

    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link = 'https://$link';
    }

    return link;
  }

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

  Future<void> _compartilharFoto() async {
    if (_obterLink().isEmpty) {
      _mostrarMensagem('Digite o link de afiliado.');
      return;
    }

    if (_imagemOriginal == null) {
      _mostrarMensagem('Escolha um print.');
      return;
    }

    final arquivo = _imagemRecortada ?? _imagemOriginal!;

    await SharePlus.instance.share(
      ShareParams(
        text: _gerarTextoDivulgacao(),
        files: [XFile(arquivo.path)],
      ),
    );
  }

  Future<void> _compartilharTexto() async {
    if (_obterLink().isEmpty) {
      _mostrarMensagem('Digite o link de afiliado.');
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: _gerarTextoDivulgacao(),
      ),
    );
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Widget _campoLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _linkController,
        decoration: InputDecoration(
          hintText: 'Link do produto / link de afiliado',
          prefixIcon: const Icon(Icons.link),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _foto() {
    if (_imagemRecortada == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          _imagemRecortada!,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _informacoes() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMAÇÕES ENCONTRADAS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'NOME DO PRODUTO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nomeProduto.isEmpty
                ? 'Produto não identificado'
                : _nomeProduto,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'PREÇO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _preco.isEmpty ? 'Não identificado' : _preco,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final temImagem = _imagemOriginal != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            _campoLink(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton.icon(
                  onPressed: _carregando ? null : _escolherPrint,
                  icon: const Icon(Icons.image_outlined, size: 32),
                  label: const Text(
                    'ESCOLHER FOTO / PRINT DO PRODUTO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.all(35),
                child: CircularProgressIndicator(),
              ),
            if (!_carregando && temImagem) _foto(),
            if (!_carregando && temImagem) _informacoes(),
            if (!_carregando && temImagem)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _limparTudo,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'LIMPAR TUDO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (!_carregando && temImagem)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _compartilharFoto,
                        icon: const Icon(Icons.image),
                        label: const Text(
                          'COMPARTILHAR FOTO + DIVULGAÇÃO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _compartilharTexto,
                        icon: const Icon(Icons.share),
                        label: const Text(
                          'COMPARTILHAR SOMENTE TEXTO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!temImagem && !_carregando)
              const Padding(
                padding: EdgeInsets.fromLTRB(35, 60, 35, 20),
                child: Text(
                  'O aplicativo identifica automaticamente o preço e o título do produto, recorta somente a área da foto e prepara a divulgação.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

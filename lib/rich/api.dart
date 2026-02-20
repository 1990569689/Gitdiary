import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';
enum FormatType {
  bold(Icons.format_bold, "BOLD"),
  italic(Icons.format_italic, "ITALIC"),
  subscript(Icons.subscript, "SUBSCRIPT"),
  superscript(Icons.superscript, "SUPERSCRIPT"),
  underline(Icons.format_underline, "UNDERLINE"),
  bullets(Icons.format_list_bulleted, "BULLETS"),
  numbers(Icons.format_list_numbered, "NUMBERS"),
  strikeThrough(Icons.format_strikethrough, "STRIKETHROUGH"),
  blockquote(Icons.format_quote, "BLOCKQUOTE"),
  indent(Icons.format_indent_increase_outlined, "INDENT"),
  outdent(Icons.format_indent_decrease, "OUTDENT"),
  alignCenter(Icons.format_align_center, "ALIGN_CENTER"),
  alignLeft(Icons.format_align_left, "ALIGN_LEFT"),
  alignRight(Icons.format_align_right, "ALIGN_RIGHT");

  final IconData icon;
  final String name;

  const FormatType(this.icon, this.name);

  // 根据图标查找对应的格式类型
  static FormatType? fromIcon(IconData icon) {
    for (var type in FormatType.values) {
      if (type.icon == icon) {
        return type;
      }
    }
    return null;
  }

  // 根据名称查找对应的格式类型
  static FormatType? fromName(String name) {
    for (var type in FormatType.values) {
      if (type.name.toUpperCase() == name.toUpperCase()) {
        return type;
      }
    }
    return null;
  }
}

enum Type {
  
  BOLD,
  ITALIC,
  SUBSCRIPT,
  SUPERSCRIPT,
  STRIKETHROUGH,
  UNDERLINE,
  H1,
  H2,
  H3,
  H4,
  H5,
  H6,
  ORDERichDLIST,
  UNORDERichDLIST,
  JUSTIFYCENTER,
  JUSTIFYFULL,
  JUSTIFYLEFT,
  JUSTIFYRIGHT
}
// 文本变化回调
typedef OnTextChangeListener = void Function(String text);

// 格式状态变化回调
typedef OnDecorationStateListener = void Function(String text, List<Type> types);

// 初始化完成回调
typedef AfterInitialLoadListener = void Function(bool isReady);

class JsApi {
  // final WebViewController _webViewController;
  InAppWebViewController webController;
  static const String _jsApiName = 'jsApi';
  String mContents = "";
  JsApi(this.webController);
  // void exec(final String trigger) {
  //   _webViewController.runJavaScript(trigger);
  // }

   Future<void> exec(final String js) async {
    if (webController == null) return;
    // 执行简单JS
    final result = await webController?.evaluateJavascript(
      source:js,
    );
    // 接收JS返回值
    if (result != null) {
     
    }
  }
  Future<String>  getData(String js) async{
    
    // 执行简单JS
    final result = await webController?.evaluateJavascript(
      source:js,
    );
    // 接收JS返回值
    if (result != null) {
      return result;
    }
    return "";
   
  }


   String convertHexColorString(int color) {
    // return String.format("#%06X", (0xFFFFFF & color));
    return "#" + (0xFFFFFF & color).toRadixString(16).padLeft(6, '0');
  }
     void loadCSS(String cssFile) {
    String jsCSSImport = "(function() {" +
      "    var head  = document.getElementsByTagName(\"head\")[0];" +
      "    var link  = document.createElement(\"link\");" +
      "    link.rel  = \"stylesheet\";" +
      "    link.type = \"text/css\";" +
      "    link.href = \"" + cssFile + "\";" +
      "    link.media = \"all\";" +
      "    head.appendChild(link);" +
      "}) ();";
    exec("javascript:" + jsCSSImport + "");
  }

   void insertHtml(String contents) {
    exec("javascript:Rich.injectFullHtml('" + contents+ "');");
    mContents = contents;
  }
  // void applyAttributes(Context context, AttributeSet attrs) {
  //   final int[] attrsArray = new int[]{
  //     android.R.attr.gravity
  //   };
  //   TypedArray ta = context.obtainStyledAttributes(attrs, attrsArray);

  //   int gravity = ta.getInt(0, NO_ID);
  //   switch (gravity) {
  //     case Gravity.LEFT:
  //       exec("javascript:Rich.setTextAlign(\"left\")");
  //       break;
  //     case Gravity.RIGHT:
  //       exec("javascript:Rich.setTextAlign(\"right\")");
  //       break;
  //     case Gravity.TOP:
  //       exec("javascript:Rich.setVerticalAlign(\"top\")");
  //       break;
  //     case Gravity.BOTTOM:
  //       exec("javascript:Rich.setVerticalAlign(\"bottom\")");
  //       break;
  //     case Gravity.CENTER_VERTICAL:
  //       exec("javascript:Rich.setVerticalAlign(\"middle\")");
  //       break;
  //     case Gravity.CENTER_HORIZONTAL:
  //       exec("javascript:Rich.setTextAlign(\"center\")");
  //       break;
  //     case Gravity.CENTER:
  //       exec("javascript:Rich.setVerticalAlign(\"middle\")");
  //       exec("javascript:Rich.setTextAlign(\"center\")");
  //       break;
  //   }

  //   ta.recycle();
  // }
   String getHtml() {
    return mContents;
  }
  // 设置对齐方式（对应Java的applyAttributes）
  void _setAlignment(AlignmentGeometry alignment) {
    if (alignment == Alignment.center) {
      exec("javascript:Rich.setVerticalAlign('middle')");
      exec("javascript:Rich.setTextAlign('center')");
    } else if (alignment == Alignment.centerLeft) {
      exec("javascript:Rich.setTextAlign('left')");
    } else if (alignment == Alignment.centerRight) {
      exec("javascript:Rich.setTextAlign('right')");
    } else if (alignment == Alignment.topCenter) {
      exec("javascript:Rich.setVerticalAlign('top')");
      exec("javascript:Rich.setTextAlign('center')");
    }
  }


   void insertMathFormula(String value)
  {
      exec("javascript: Rich.initMathJax();");
      exec("javascript: Rich.insertMathFormula('"+value+"');");
    
  }


   void insertTag(String value)
  {
       exec("javascript: Rich.insertTag('"+value+"');");
    
  }
   void insertCollapsible(String value)
  {
       exec("javascript: Rich.insertCollapsible('点击展开/收起','"+value+"');");
    
  }

  void setGenerateToc()
  {
       exec("javascript:Rich.generateToc();");
    
  }
   void setEditorFontColor(int color) {
    String hex = convertHexColorString(color);
    exec("javascript:Rich.setBaseTextColor('" + hex + "');");
  }

     void setBackgroundColor(int color) {
    String hex = convertHexColorString(color);
    exec("javascript:Rich.setBackgroundColor('" + hex + "');");
  }
  void insertTable(String rows,String cols)
  {
    // 插入3行3列表格
// webViewController.evaluateJavascript('Rich.insertTable(3, 3)');
// // 给表格新增一行
// webViewController.evaluateJavascript('Rich.editTable("addRow")');
     exec("javascript:Rich.insertTable("+rows+", "+cols+")");
  }
  void editTable()
  {
    exec('javascript:Rich.editTable("addRow")');
  }
   void setEditorFontSize(int px) {
    exec("javascript:Rich.setBaseFontSize('" + px.toString() + "px');");
  }

     void setBackground(String url) {
    exec("javascript:Rich.setBackgroundImage('url(" + url + ")');");
  }

   void setEditorWidth(int px) {
    exec("javascript:Rich.setWidth('" + px.toString() + "px');");
  }

   void setEditorHeight(int px) {
    exec("javascript:Rich.setHeight('" + px.toString() + "px');");
  }

   void setPlaceholder(String placeholder) {
    exec("javascript:Rich.setPlaceholder('" + placeholder + "');");
  }

   void setInputEnabled(bool inputEnabled) {
    exec("javascript:Rich.setInputEnabled(" + inputEnabled.toString() + ")");
  }

   void undo() {
    exec("javascript:Rich.undo();");
  }

   void redo() {
    exec("javascript:Rich.redo();");
  }

   void setBold() {
    exec("javascript:Rich.setBold();");
  }

   void setItalic() {
    exec("javascript:Rich.setItalic();");
  }

   void setSubscript() {
    exec("javascript:Rich.setSubscript();");
  }

   void setSuperscript() {
    exec("javascript:Rich.setSuperscript();");
  }

   void setStrikeThrough() {
    exec("javascript:Rich.setStrikeThrough();");
  }

   void setUnderline() {
    exec("javascript:Rich.setUnderline();");
  }

   void setTextColor(int color) {
    // exec("javascript:Rich.prepareInsert();");
    String hex = convertHexColorString(color);
    exec("javascript:Rich.setTextColor('" + hex + "');");
  }

   void setTextBackgroundColor(int color) {
    // exec("javascript:Rich.prepareInsert();");
    String hex = convertHexColorString(color);
    exec("javascript:Rich.setTextBackgroundColor('" + hex + "');");
  }

   void setFontSize(String fontSize) {
 
    exec("javascript:Rich.setFontSize('" + fontSize + "px');");
  }
   void setFontName(String name) {
 
    exec("javascript:Rich.setFontName('" + name + "');");
  }
   void removeFormat() {
    exec("javascript:Rich.removeFormat();");
  }

   void setHeading(int heading) {
    exec("javascript:Rich.setHeading('" + heading.toString() + "');");
  }

   void setIndent() {
    exec("javascript:Rich.setIndent();");
  }

   void setOutdent() {
    exec("javascript:Rich.setOutdent();");
  }

   void setAlignLeft() {
    exec("javascript:Rich.setJustifyLeft();");
  }

   void setAlignCenter() {
    exec("javascript:Rich.setJustifyCenter();");
  }

   void setAlignRight() {
    exec("javascript:Rich.setJustifyRight();");
  }

   void setBlockquote() {
    exec("javascript:Rich.setBlockquote();");
  }

   void setBullets() {
    exec("javascript:Rich.setBullets();");
  }

   void setNumbers() {
    exec("javascript:Rich.setNumbers();");
  }
    void setMobileTextColor(String type) {
    exec("javascript:Rich.setMobileTextColor('"+type+"');");
  }
    void insertDivider() {
    exec("javascript:Rich.insertDivider();");
  }  void insertCodeBlock() {
    exec("javascript:Rich.insertCodeBlock();");
  } void insertDateTime() {
    exec("javascript:Rich.insertDateTime();");
  }

  

   void setTodo(String text,String value) {
     exec("javascript:Rich.prepareInsert();");
     exec("javascript:Rich.setTodo('" + text + "', '" + value + "');");
  }
   void insertImage(String url, String alt) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertImage('" + url + "', '" + alt + "');");
  }

  void insertImageBase64(String base64, String alt) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertImageBase64('" + base64 + "', '" + alt + "');");
  }
  /**
   * the image according to the specific width of the image automatically
   *
   * @param url
   * @param alt
   * @param width
   */
   void insertImageW(String url, String alt, int width) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertImageW('" + url + "', '" + alt + "','" + width.toString() + "');");
  }

  /**
   * {@link RichEditor#insertImage(String, String)} will show the original size of the image.
   * So this method can manually process the image by adjusting specific width and height to fit into different mobile screens.
   *
   * @param url
   * @param alt
   * @param width
   * @param height
   */
   void insertImageWH(String url, String alt, int width, int height) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertImageWH('" + url + "', '" + alt + "','" + width.toString() + "', '" + height.toString() + "');");
  }

   void insertVideo(String url) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertVideo('" + url + "');");
  }

   void insertVideoW(String url, String width) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertVideoW('" + url + "', '" + width.toString() + "');");
  }

   void insertVideoWH(String url, int width, int height) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertVideoWH('" + url + "', '" + width.toString() + "', '" + height.toString() + "');");
  }

   void insertAudio(String url) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertAudio('" + url + "');");
  }

   void insertLink(String href, String title) {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertLink('" + href + "', '" + title + "');");
  }

   void focusEditor() {
    // requestFocus();
    exec("javascript:Rich.focus();");
  }

   void clearFocusEditor() {
    exec("javascript:Rich.blurFocus();");
  }
 void insertInfoCard() {
    exec("javascript:Rich.prepareInsert();");
    exec("javascript:Rich.insertInfoCard();");
  }
   void insertVideoBliBli(String bv) {
    insertHtml("<iframe src=\"https://player.bilibili.com/player.html?isOutside=true&aid=114665409480710&bvid="+bv+"&cid=30444423919&p=1\" scrolling=\"no\" border=\"0\" frameborder=\"no\" width=\"100%\" framespacing=\"0\" allowfullscreen=\"true\"></iframe>");
  }
  





}

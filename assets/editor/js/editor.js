
let vditor;
document.addEventListener('DOMContentLoaded', () => {
    // 创建Vditor实例，配置最简即可
    vditor = new Vditor('vditor', {
        cache: {
            id: 'EditorCache', // 缓存键名
            enable: false         // 启用缓存
        },
        counter: {
            enable: true
        },
        // height: window.innerHeight / 2,
        width: '100%',
        height: '100%', // 移动端高度自适应，替代固定高度
        // minHeight: '200px', // 移动端最小高度，防止编辑器过矮
        // maxHeight: '70vh', // 移动端最大高度，防止超出屏幕，配合滚动
        mode: 'ir', // 即时渲染，移动端体验最佳
        touch: true, // 开启移动端触摸事件优化（核心）
        input: {
            spellcheck: false, // 关闭浏览器拼写检查，移动端易误触
            autocomplete: 'off', // 关闭自动补全，避免干扰
            autocorrect: 'off', // 关闭自动修正
        },
        preview: {
            // theme: {
            //     current: "dark"
            // },
            markdown: {
                mark: true
            },
            maxWidth: '100%', // 预览区宽度100%，无横向溢出
            overflow: 'hidden', // 预览区禁止横向滚动
        },
        outline: {
            enable: false, // 移动端关闭大纲，节省空间
        },
        resize: false, // 移动端禁止手动缩放编辑器，防止溢出
        initialValue: '',
        placeholder: "请输入Markdown内容..."// 初始值，可直接在这里赋值，无需额外调用setValue // 所见即所得模式，ir（即时渲染）/sv（分屏）也可
    });
    // vditor.setValue('这是测试的setValue内容\n支持markdown换行\n**加粗文本**', false);
    // testSetValue();
    // 实例创建后直接调用setValue（也能生效）
    // vditor.setValue('初始化直接赋值的内容', false);
});
/**
 * 通用工具函数：判断Vditor实例是否有效，WebView所有接口前置校验
 */
function checkVditorInstance() {
    if (!vditor || typeof vditor !== 'object') {
        console.error('Vditor实例未创建或已失效');
        // WebView交互可返回特定标识，方便原生判断
        return false;
    }
    return true;
}
function setValue(data) {
    // 先打印实例，确认不是undefined/null（关键调试步骤）
    console.log('Vditor实例：', vditor);
    if (!vditor) {
        alert('实例未创建！');
        return;
    }
    // 调用setValue，参数正确传值（不要写clearStack = false，直接传false）
    vditor.setValue(decodeURIComponent(escape(atob(data))), false);
}


function getEditorValue() {
    return vditor.getValue();
}

function insertValue(data) {
  console.log('Vditor实例：', vditor);
    if (!vditor) {
        alert('实例未创建！');
        return;
    }
    // 调用setValue，参数正确传值（不要写clearStack = false，直接传false）
    vditor.insertValue(decodeURIComponent(escape(atob(data))), false);
    // ameSetValue(value);
}

ameGetValue = () => {
    return vditor.getValue();
};

//在焦点处插入内容
ameInsertValue = (value) => {
    vditor.insertValue(value);
};

//聚焦到编辑器
ameFocus = () => {
    vditor.focus();
};

//失焦
ameBlur = () => {
    vditor.blur();
};

//禁用
ameDisabled = () => {
    vditor.disabled();
};

//解除编辑器禁用
ameEnable = () => {
    vditor.enable();
};

//选中从 start 开始到 end 结束的字符串
ameSetSelection = (start, end) => {
    vditor.setSelection(start, end);
};

//返回选中的字符串
ameGetSelection = () => {
    return vditor.getSelection();
};

//设置编辑器内容
// ameSetValue = (value) => {
//     vditor.setValue(value, false);
// };

//获取焦点位置
ameGetCursorPosition = () => {
    return JSON.stringify(vditor.getCursorPosition());
};

//删除选中内容
ameDeleteValue = () => {
    vditor.deleteValue();
};

//更新选中内容
ameUpdateValue = (value) => {
    vditor.updateValue(value);
};
ameClearCache();
//清除缓存
ameClearCache = () => {
    vditor.clearCache();
};
ameDisabledCache();
//禁用缓存
ameDisabledCache = () => {
    vditor.disabledCache();
};

//启用缓存
ameEnableCache = () => {
    vditor.enableCache();
};

//设置预览模式
ameSetPreviewMode = (mode) => {
    //alert(mode);
    console.log(mode);

    vditor.setPreviewMode(mode);
};

//设置模式
ameSetWysiwyg = (mode) => {
    vditor.setWysiwyg(mode);
};

//消息提示
ameTip = (text, time) => {
    vditor.tip(text, time);
};

ameUndo = () => {
    vditor.undo();
};

ameRedo = () => {
    vditor.redo();
};

ameSetBold = () => {
    vditor.setBold();
};

ameSetH1 = () => {
    vditor.setH1();
};

ameSetH2 = () => {
    vditor.setH2();
};

ameSetH3 = () => {
    vditor.setH3();
};

ameSetH4 = () => {
    vditor.setH4();
};

ameSetH5 = () => {
    vditor.setH5();
};

ameSetH6 = () => {
    vditor.setH6();
};

ameSetItalic = () => {
    vditor.setItalic();
};

ameSetStrike = () => {
    vditor.setStrike();
};

ameSetLine = () => {
    vditor.setLine();
};

ameSetQuote = () => {
    vditor.setQuote();
};

ameSetList = () => {
    vditor.setList();
};

ameSetOrdered = () => {
    vditor.setOrdered();
};

ameSetCheck = () => {
    vditor.setCheck();
};

ameSetCode = () => {
    vditor.setCode();
};

ameSetInlineCode = () => {
    vditor.setInlineCode();
};

ameSetLink = () => {
    vditor.setLink();
};

ameSetTable = () => {
    vditor.setTable();
};

ameGetHtml = () => {
    // console.log(vditor.getHTML());

    // let str = vditor.getHTML();

    // let str1 = str.replace(new RegExp("\\u003C","gm"),"<")

    // return str1
    return vditor.getHTML();
    // vditor.getHTML().then(res => {
    //   ameBridge.getHtml(res)
    // })
};

ameHtml2md = (value) => {
    return vditor.html2md(value);
    // vditor.html2md(value).then(res => {
    //   ameBridge.html2md(res)
    // })
};

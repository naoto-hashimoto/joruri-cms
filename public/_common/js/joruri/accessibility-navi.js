// Accessibility Navigation
// require "jquery-cookie.js"

$(function() {
  var navi = new JoruriAcNavi();
});

/**
 * navigation class
 */
function JoruriAcNavi() {
  var self = this;

  // properties
  this.fontBase   = $('.naviFont .base').length ? $('.naviFont .base')   : null;
  this.fontSmall  = $('.naviFont .small').length ? $('.naviFont .small') : null;
  this.fontBig    = $('.naviFont .big').length ? $('.naviFont .big')   : null;
  this.fontView   = $('.naviFont .view').length ? $('.naviFont .view')  : null;
  this.fontSize   = this.fontView ? this.fontView.html() : '100%';
  this.themeWhite = $('.naviTheme .white').length ? $('.naviTheme .white') : null;
  this.themeBlue  = $('.naviTheme .blue').length ? $('.naviTheme .blue') : null;
  this.themeBlack = $('.naviTheme .black').length ? $('.naviTheme .black') : null;
  this.rubyLink   = $('.naviRuby .ruby').length ? $('.naviRuby .ruby') : null;
  this.talkLink   = $('.naviTalk .talk').length ? $('.naviTalk .talk') : null;
  this.talkPlayer = $('.naviTalk .player').length ? $('.naviTalk .player') : null;
  this.noticeView = $('#headerBody').length ? $('#headerBody') : null;

  // methods
  this.changeFont   = JoruriAcNavi_changeFont;
  this.relativeFont = JoruriAcNavi_relativeFont;
  this.changeTheme  = JoruriAcNavi_changeTheme;
  this.ruby         = JoruriAcNavi_ruby;
  this.talk         = JoruriAcNavi_talk;
  this.notice       = JoruriAcNavi_notice;

  // reflect
  this.changeFont();
  this.changeTheme();
  this.ruby();

  // events
  if (this.fontBase) this.fontBase.mousedown(function() {
    return self.changeFont('100%');
  });
  if (this.fontSmall) this.fontSmall.click(function() {
    return self.changeFont(self.relativeFont('small'));
  });
  if (this.fontBig) this.fontBig.click(function() {
    return self.changeFont(self.relativeFont('big'));
  });
  if (this.themeWhite) this.themeWhite.click(function() {
    return self.changeTheme('white');
  });
  if (this.themeBlue) this.themeBlue.click(function() {
    return self.changeTheme('blue');
  });
  if (this.themeBlack) this.themeBlack.click(function() {
    return self.changeTheme('black');
  });
  if (this.rubyLink) this.rubyLink.click(function() {
    $(this).toggleClass('current');
    return self.ruby($(this).attr('class').match(/current/) == "current");
  });
  if (this.talkLink) this.talkLink.click(function() {
    $(this).toggleClass('current');
    return self.talk($(this).attr('class').match(/current/) == "current");
  });
}

/**
 * font size
 */
function JoruriAcNavi_relativeFont(mode) {
  var size = this.fontSize.match(/^[0-9]+/);
  if (!size || !this.fontSize.match(/%$/)) size = '100';
  size = parseInt(size);
  if (mode == 'small' && size > 60) size -= 20;
  if (mode == 'big' && size < 200) size += 20;
  return String(size) + '%';
}
function JoruriAcNavi_changeFont(value) {
  if (value) {
    $.cookie('navigation_font_size', value, { path: '/' });
  } else {
    value = $.cookie('navigation_font_size');
    if (!value) value = this.fontSize;
  }
  if (this.fontView) {
    this.fontView.html(value);
  }
  this.fontSize = value;
  $('body').css('fontSize', value);
  return false;
}

/**
 * theme
 */
function JoruriAcNavi_changeTheme(value) {
  if (value) {
    $.cookie('navigation_theme', value, { path: '/' });
  } else {
    value = $.cookie('navigation_theme');
    if (!value) return false;
  }
  var links = $('link[rel*=alternate]');
  links.each(function() { // reset
    var title = $(this).attr('title');
    this.disabled = true;
    $('.naviTheme .' + title).removeClass('current');
  });
  links.each(function() { // current
    if ($(this).attr('title') == value) {
      this.disabled = false;
      $('.naviTheme .' + value).addClass('current');
    }
  });
  return false;
}

/**
 * ruby
 */
function JoruriAcNavi_ruby(flag) {
  var path;

  if (flag == true) { // redirect
    $.cookie('navigation_ruby', 'on', { path: '/' });

    if (location.pathname.search(/\/$/i) != -1) {
      path = location.pathname + "index.html.r";
    } else if (location.pathname.search(/\.html\.mp3$/i) != -1) {
      path = location.pathname.replace(/\.html\.mp3$/, ".html.r");
    } else if (location.pathname.search(/\.html$/i) != -1) {
      path = location.pathname.replace(/\.html$/, ".html.r");
    } else {
      path = location.pathname.replace(/#.*/, '');
    }
  } else if (flag == false) { // redirect
    $.cookie('navigation_ruby', 'off', { path: '/' });
    if (location.pathname.search(/\.html\.r$/i) != -1) {
      path = location.pathname.replace(/\.html\.r$/, ".html");
    } else {
      location.reload();
    }
  } else if ($.cookie('navigation_ruby') == "on") { // render: rubied
    if (location.pathname.search(/\/$/i) != -1) {
      path = location.pathname + "index.html.r";
    } else if (location.pathname.search(/\.html$/i) != -1) {
      path = location.pathname.replace(/\.html$/, ".html.r");
    } else {
      if (this.rubyLink) this.rubyLink.addClass('current');
      this.notice();
    }
  } else { // render: not rubied
    if (this.rubyLink) this.rubyLink.removeClass('current');
  }
  if (path) {
    var host = location.protocol + "//" + location.hostname + (location.port ? ':' + location.port : '');
    location.href = host + path + location.search;
    return;
  }
  return false;
}

/**
 * talk
 */
function JoruriAcNavi_talk(flag) {
  this.notice();

  var uri   = location.pathname;
  var now   = new Date();
  var param = '?' + now.getDay() + now.getHours() + now.getMinutes();

  if (uri.match(/\/$/)) uri += 'index.html';
  uri  = uri.replace(/\.html\.r$/, '.html');
  uri += '.mp3' + param;

  var host = location.protocol + "//" + location.hostname + (location.port ? ':' + location.port : '');

  if (!this.talkPlayer) {
    location.href = host + uri;
    return false;
  }

  if (this.talkPlayer.html() == '') { // play
    var html = '<audio src=" ' + host + uri + '" id="naviTalkPlayer" controls autoplay />';
    this.talkPlayer.html(html);
  } else { // stop
    if ($.cookie('navigation_ruby') != 'on') $('#navigationNotice').remove();
    this.talkPlayer.html('');
  }
  return false;
}

/**
 * notice
 */
function JoruriAcNavi_notice() {
  var noticeId = 'navigationNotice';
  var notice = $('#' + noticeId);
  if (this.noticeView && !notice.length) {
    var text = '????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????';
    this.noticeView.append('<div id="' + noticeId + '">' + text + '</div>');
  }
}

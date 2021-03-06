$ = require 'jquery'
markdown = require 'markdown'
toastr = require 'toastr'
Router = require 'router'
Handlebars = require 'hbsfy/runtime'
FastClick = require 'fast-click'
Upload = require '../../components/upload-image'
Chart = require '../../components/chart'
Iconpicker = require '../../components/iconpicker'
require '../../components/csrf'

adou.backgroundSuffix = 'background1600'
toastr.options.positionClass = 'toast-bottom-right'

# 组件
components =
  logo: require '../../templates/components/logo.hbs'
  profile: require '../../templates/components/profile.hbs'
  section: require '../../templates/components/section.hbs'
  sectionAdd: require '../../templates/components/section-add.hbs'
  sectionTitle: require '../../templates/components/section-title.hbs'
  sectionNavigation: require '../../templates/components/section-navigation.hbs'
  point: require '../../templates/components/point.hbs'
  pointAdd: require '../../templates/components/point-add.hbs'
  pointEdit: require '../../templates/components/point-edit.hbs'

# 页面
pages =
  list: require '../../templates/pages/story/list.hbs'
  detail: require '../../templates/pages/story/detail.hbs'

Handlebars.registerPartial 'logo', components.logo
Handlebars.registerPartial 'profile', components.profile
Handlebars.registerPartial 'section', components.section
Handlebars.registerPartial 'section-add', components.sectionAdd
Handlebars.registerPartial 'section-title', components.sectionTitle
Handlebars.registerPartial 'section-navigation', components.sectionNavigation
Handlebars.registerPartial 'point', components.point
Handlebars.registerPartial 'point-add', components.pointAdd
Handlebars.registerPartial 'point-edit', components.pointEdit

Handlebars.registerHelper 'markdown', (text) ->
  return markdown.toHTML text

Handlebars.registerHelper 'circle', (bubble) ->
  return '<div class="circle"></div>' if not bubble
  progress = if /^([0-9]{1,3}\%)$/.test(bubble) then parseInt bubble.replace('%', ''), 10 else null
  return "<div class='circle circle-general'><div class='chart' data-progress='#{progress}'></div></div>" if progress && progress >= 0 && progress <= 100
  return "<div class='circle circle-general'><i class='fa fa-#{bubble.substr(5)}'></i></div>" if 0 is bubble.indexOf 'icon-'
  return "<div class='circle circle-large'><div class='visible'>#{bubble}</div></div>"

Handlebars.registerHelper 'circle-type', (bubble) ->
  return '' if not bubble
  progress = if /^([0-9]{1,3}\%)$/.test(bubble) then parseInt bubble.replace('%', ''), 10 else null
  return 'progress' if progress && progress >= 0 && progress <= 100
  return 'icon' if 0 is bubble.indexOf 'icon-'
  return 'text'

{upyun, preloaded} = adou

$ ->
  FastClick.attach document.body

  $wrap = $ '#wrap'
  $list = $ '#list'
  $detail = $ '#detail'

  oChart = new Chart container: $detail
  oIconpicker = new Iconpicker container: $detail

  resize = ->
    $window = $ window
    width = $window.width()
    if width < 800
      adou.backgroundSuffix = 'background800'
    else if width > 600 and width < 1200
      adou.backgroundSuffix = 'background1024'
    else
      adou.backgroundSuffix = 'background1600'

    $wrap.height $window.height()

  resize()

  $(window).on 'resize', resize

  $('.feedback').tooltip()

  _list = (data) ->
    $list.html pages.list data

    # 新建故事
    $('#add').on 'click', (event) ->
      event.preventDefault()
      $.ajax
        url: '/api/stories'
        type: 'POST'
        dataType: 'json'
      .done (story) ->
        router.setRoute "stories/#{story.id}"
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '新建故事出错!'

    $items = $ '#items'
    $items.on 'click', 'a .trash', (event) ->
      event.preventDefault()
      event.stopPropagation()
      $(this).closest('.actions').addClass('open').one 'mouseleave', -> $(this).removeClass 'open'

    $items.on 'click', 'a .cancel', (event) ->
      event.preventDefault()
      event.stopPropagation()
      $(this).closest('.actions').removeClass('open').unbind 'mouseleave'

    $items.on 'click', 'a .remove', (event) ->
      event.preventDefault()
      event.stopPropagation()
      $item = $(this).closest 'a.item'
      $.ajax
        url: "/api/stories/#{$item.data('id')}"
        type: 'DELETE'
        dataType: 'json'
      .done ->
        $item.addClass('fadeOut').one $.support.transition.end, -> $item.remove()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '删除故事出错!'

    $list.unbind($.support.transition.end).one $.support.transition.end, -> $detail.html ''
    $wrap.removeClass 'bige'

  _detail = (data) ->
    data.backgroundSuffix = adou.backgroundSuffix
    $detail.html pages.detail data

    $profile = $ '#profile'

    # 刷新
    refreshSection = ->
      sections = []
      $detail.find('.section').each (index) ->
        $el = $ this
        if 0 is index%2 then $el.addClass 'section-black' else $el.removeClass 'section-black'
        if $el.data 'id'
          sections.push
            id: $el.data 'id'
            title: $el.find('.section-title .name').text()

      $profile.find('.nav').html components.sectionNavigation sections: sections

    refreshPoint = (noSortable) ->
      $detail.find('.point').each (index) ->
        $el = $ this
        if 0 is index%2 then $el.removeClass 'point-right' else $el.addClass 'point-right'

      if not noSortable
        $detail.find('.points').each ->
          $el = $ this
          $el.sortable 'destroy'
          $el.sortable
            forcePlaceholderSize: true
            handle: '.circle'
            items: '.point-data'
            placeholder: '<div class="point point-placeholder"><div class="point-container"></div></div>'
          .on 'dragenter.h5s', ->
            $detail.find('.point:not(.sortable-dragging)').each (index) ->
              $el = $ this
              if 0 is index%2 then $el.removeClass 'point-right' else $el.addClass 'point-right'
          .on 'sortupdate', (event) ->
            refreshPoint true
            $el = $ event.target
            points = []
            $el.find('.point-data').each -> points.push $(this).data 'id'
            $.ajax
              url: "/api/sections/#{$el.closest('.section').data('id')}"
              type: 'PATCH'
              data: points: points
              dataType: 'json'
            .fail (res) ->
              error = res.responseJSON.error
              if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
              toastr.error errors.join('<br>'), '节点排序出错!'
              window.location.reload()

    refreshOnePieChart = ($el) ->
      $el.html('').data 'easyPieChart', null
      if not $el.data 'easyPieChart'
        $el.easyPieChart
          scaleColor: false
          size: 31
          lineWidth: 15.5
          barColor: $el.css 'color'
          lineCap: 'butt'
          trackColor: 'transparent'

        $el.on 'mouseenter', ->
          pie = $el.data 'easyPieChart'
          pie.update 0
          pie.update $el.data 'progress'

      $el.data('easyPieChart').update $el.data 'progress'

    refreshPieChart = ->
      $detail.find('.circle .chart').each -> refreshOnePieChart $ this

    refreshBtnPicture = ->
      $detail.find('.point .btn-picture').each ->
        $el = $ this
        if 0 is $el.find('[type="file"]').length
          pictureUpload = new Upload()
          pictureUpload.assignBrowse $el[0]
          pictureUpload.on 'filesAdded', ->
            $el.addClass 'loading'
          pictureUpload.on 'filesSubmitted', (err) ->
            if err
              pictureUpload.flow.cancel()
              toastr.error err, '上传图片出错!'
              return $el.removeClass 'loading'
            pictureUpload.upload()
          pictureUpload.on 'fileError', (file, message) ->
            data = JSON.parse message
            pictureUpload.flow.cancel()
            toastr.error data.message, '上传图片出错!'
            $el.removeClass 'loading'
          pictureUpload.on 'fileSuccess', (file, message) ->
            pictureUpload.flow.cancel()
            message = JSON.parse message
            image = upyun.buckets['starry-images'] + message.url
            window.setTimeout ->
              $el.removeClass 'loading'
              $pointPicture = $el.closest('.point').find '.point-picture img'
              if $pointPicture.length
                $pointPicture.attr 'src', image
              else
                $el.closest('.point').find('.point-body').after "<div class='point-picture'><img class='picture-point-image' src='#{image}!picture'></div>"

              $el.next('[name="image"]').val image
            , 800

    refresh = ->
      refreshSection()
      refreshPoint()
      refreshPieChart()
      refreshBtnPicture()

    story = data.story
    points = []

    for section in story.sections
      for point in section.points
        points[point.id] = point

    # 替换背景图
    $replaceBackground = $ '#replaceBackground'
    replaceBackgroundUpload = new Upload()
    replaceBackgroundUpload.assignBrowse $replaceBackground[0]
    replaceBackgroundUpload.on 'filesAdded', ->
      $replaceBackground.addClass 'loading'
    replaceBackgroundUpload.on 'filesSubmitted', (err) ->
      if err
        replaceBackgroundUpload.flow.cancel()
        toastr.error err, '上传图片出错!'
        return $replaceBackground.removeClass 'loading'
      replaceBackgroundUpload.upload()
    replaceBackgroundUpload.on 'fileError', (file, message) ->
      data = JSON.parse message
      replaceBackgroundUpload.flow.cancel()
      toastr.error data.message, '上传图片出错!'
      $replaceBackground.removeClass 'loading'
    replaceBackgroundUpload.on 'fileSuccess', (file, message) ->
      replaceBackgroundUpload.flow.cancel()
      message = JSON.parse message
      image = upyun.buckets['starry-images'] + message.url
      $.ajax
        url: "/api/stories/#{story.id}"
        type: 'PATCH'
        data: background: image
        dataType: 'json'
      .done ->
        window.setTimeout ->
          $replaceBackground.removeClass 'loading'
          $replaceBackground.closest('.section-background').css 'backgroundImage', "url(#{image}!#{adou.backgroundSuffix})"
        , 800
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '上传图片出错!'
        $replaceBackground.removeClass 'loading'

    # 上传头像
    $profileImage = $ '#profileImage'
    profileImageUpload = new Upload()
    profileImageUpload.assignBrowse $profileImage[0]
    profileImageUpload.assignDrop $profileImage[0]
    profileImageUpload.on 'filesAdded', ->
      $profileImage.closest('.profile-image').addClass 'loading'
    profileImageUpload.on 'filesSubmitted', (err) ->
      if err
        profileImageUpload.flow.cancel()
        toastr.error err, '上传图片出错!'
        return $profileImage.removeClass('loading').addClass 'done'
      profileImageUpload.upload()
    profileImageUpload.on 'fileError', (file, message) ->
      data = JSON.parse message
      profileImageUpload.flow.cancel()
      toastr.error data.message, '上传图片出错!'
      $profileImage.removeClass('loading').addClass 'done'
    profileImageUpload.on 'fileSuccess', (file, message) ->
      profileImageUpload.flow.cancel()
      message = JSON.parse message
      image = upyun.buckets['starry-images'] + message.url
      $.ajax
        url: "/api/stories/#{story.id}"
        type: 'PATCH'
        data: cover: image
        dataType: 'json'
      .done ->
        window.setTimeout ->
          $profileImage.removeClass('loading').addClass 'done'
          $profileImage.css 'backgroundImage', "url(#{image}!avatar)"
        , 800
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '上传图片出错!'
        $profileImage.removeClass('loading').addClass 'done'

    # 主题
    $themes = $ '#themes'
    $('body').attr 'class', story.theme if story.theme

    $themes.on 'click', 'a', (event) ->
      event.preventDefault()
      theme = $(this).data 'color'
      $.ajax
        url: "/api/stories/#{story.id}"
        type: 'PATCH'
        data: theme: theme
        dataType: 'json'
      .done ->
        $('body').attr 'class', theme
        refresh()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '切换主题出错!'

    # 简介
    $profile.on 'click', '.profile .edit', (event) ->
      event.preventDefault()
      $profile.addClass('edit').find('[name="title"]').focus()

    $profile.on 'click', '.profile-edit .cancel', (event) ->
      event.preventDefault()
      $profile.removeClass 'edit'

    $profile.on 'submit', '.profile-edit', (event) ->
      event.preventDefault()
      $form = $ this
      $submit = $form.find 'button[type="submit"]'
      $submit.button 'loading'
      $.ajax
        url: "/api/stories/#{story.id}"
        type: 'POST'
        data: $form.serialize()
        dataType: 'json'
      .done (story) ->
        $submit.button 'reset'
        $profile.html components.profile story
        $profile.removeClass 'edit'
        refreshSection()
      .fail (res) ->
        $submit.button 'reset'
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '更新简介出错!'

    # 片段
    sections = (section.id for section in story.sections)

    $detail.find('.container').on 'focusin', '.section-add input', (event) ->
      event.preventDefault()
      $(this).closest('.input-group').addClass 'open'

    $detail.find('.container').on 'focusout', '.section-add input', (event) ->
      event.preventDefault()
      $(this).closest('.input-group').removeClass 'open'

    $detail.find('.container').on 'submit', '.section-add', (event) ->
      event.preventDefault()
      $form = $ this
      $.ajax
        url: "/api/stories/#{story.id}/sections"
        type: 'POST'
        data: $form.serialize()
        dataType: 'json'
      .done (section) ->
        $form.find('input[name="title"]').val('').blur()
        $form.closest('.section').after components.section section
        refresh()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '添加片段出错!'

    $detail.find('.container').on 'click', '.section-title .rename', (event) ->
      event.preventDefault()
      $(this).closest('.section-title').addClass('edit').find('[name="title"]').focus()

    $detail.find('.container').on 'submit', '.section-rename', (event) ->
      event.preventDefault()
      $form = $ this
      sectionId = $form.closest('.section').data 'id'
      $.ajax
        url: "/api/sections/#{sectionId}"
        type: 'PATCH'
        data: $form.serialize()
        dataType: 'json'
      .done (section) ->
        $form.closest('.section-title').removeClass('edit').html components.sectionTitle section
        refreshSection()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '重命名出错!'

    $detail.find('.container').on 'click', '.section-title .down', (event) ->
      event.preventDefault()
      $section =  $(this).closest '.section'
      id = $section.data 'id'
      index = sections.indexOf id
      sections.splice index, 1
      sections.splice index + 1, 0, id
      $.ajax
        url: "/api/stories/#{story.id}"
        type: 'PATCH'
        data: sections: sections
        dataType: 'json'
      .done ->
        $section.next().after $section
        refresh()
        $('html, body').animate { scrollTop: $section.position().top }, 600
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '移动片段出错!'

    $detail.find('.container').on 'click', '.section-title .trash', (event) ->
      event.preventDefault()
      $(this).closest('.confirm').addClass('open').one 'mouseleave', -> $(this).removeClass 'open'

    $detail.find('.container').on 'click', '.section-title .cancel', (event) ->
      event.preventDefault()
      $(this).closest('.confirm').removeClass('open').unbind 'mouseleave'

    $detail.find('.container').on 'click', '.section-title .remove', (event) ->
      event.preventDefault()
      $section = $(this).closest '.section'
      $.ajax
        url: "/api/stories/#{story.id}/sections/#{$section.data('id')}"
        type: 'DELETE'
        dataType: 'json'
      .done ->
        $section.remove()
        refresh()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '删除片段出错!'

    # 节点
    $detail.find('.container').on 'submit', '.point-add', (event) ->
      event.preventDefault()
      $form = $ this
      sectionId = $form.closest('.section').data 'id'
      $.ajax
        url: "/api/sections/#{sectionId}/points"
        type: 'POST'
        data: $form.serialize()
        dataType: 'json'
      .done (point) ->
        points[point.id] = point
        $beforePoint = $ components.point point
        $point = $form.closest '.point'
        $point.before $beforePoint
        $point.find('.point-picture').remove()
        $form.replaceWith components.pointAdd()
        refreshPoint()
        refreshBtnPicture()
        $chart = $point.find '.chart'
        refreshOnePieChart $chart if $chart.length
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '添加节点出错!'

    $detail.find('.container').on 'click', '.point .actions .trash', (event) ->
      event.preventDefault()
      $(this).closest('.confirm').addClass('open').one 'mouseleave', -> $(this).removeClass 'open'

    $detail.find('.container').on 'click', '.point .actions .cancel', (event) ->
      event.preventDefault()
      $(this).closest('.confirm').removeClass('open').unbind 'mouseleave'

    $detail.find('.container').on 'click', '.point .actions .remove', (event) ->
      event.preventDefault()
      $section = $(this).closest '.section'
      $point = $(this).closest '.point'
      $.ajax
        url: "/api/sections/#{$section.data('id')}/points/#{$point.data('id')}"
        type: 'DELETE'
        dataType: 'json'
      .done (point) ->
        delete points[point.id]
        $point.remove()
        refreshPoint()
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '删除节点出错!'

    $detail.find('.container').on 'click', '.point .actions .edit', (event) ->
      event.preventDefault()
      $point = $(this).closest '.point'
      $pointEdit = $ components.pointEdit points[$point.data('id')]
      $point.replaceWith $pointEdit
      oChart.as $pointEdit.find '[rel-chart="yes"]'
      oIconpicker.as $pointEdit.find '[rel-iconpicker="yes"]'
      refreshPoint()
      refreshBtnPicture()

    $detail.find('.container').on 'click', '.point .point-edit .cancel', (event) ->
      event.preventDefault()
      $pointEdit = $(this).closest '.point'
      $point = $ components.point points[$pointEdit.data('id')]
      $pointEdit.replaceWith $point
      $chart = $point.find '.chart'
      refreshOnePieChart $chart if $chart.length

    $detail.find('.container').on 'submit', '.point-edit', (event) ->
      event.preventDefault()
      $form = $ this
      pointId = $form.closest('.point').data 'id'
      $.ajax
        url: "/api/points/#{pointId}"
        type: 'POST'
        data: $form.serialize()
        dataType: 'json'
      .done (point) ->
        points[point.id] = point
        $pointEdit = $form.closest '.point'
        $point = $ components.point points[$pointEdit.data('id')]
        $pointEdit.replaceWith $point
        refreshPoint()
        $chart = $point.find '.chart'
        refreshOnePieChart $chart if $chart.length
      .fail (res) ->
        error = res.responseJSON.error
        if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
        toastr.error errors.join('<br>'), '更新节点出错!'

    refresh()
    $list.unbind($.support.transition.end).one $.support.transition.end, ->
      $list.html ''
      $('html, body').scrollTop 0
      $detail.removeClass 'change'

    $wrap.addClass 'bige'

  router = new Router()

  # 列表
  router.on '/stories\/?/?', ->
    if preloaded
      _list { stories: preloaded.stories }
      return preloaded = null

    $.ajax
      url: '/api/stories'
      type: 'GET'
      dataType: 'json'
    .done (res) ->
      _list { stories: res }
    .fail (res) ->
      error = res.responseJSON.error
      if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
      toastr.error errors.join('<br>'), '获取列表数据出错!'

  # 详情
  router.on '/stories/:id', (id) ->
    if preloaded
      _detail { story: preloaded.story }
      return preloaded = null

    $.ajax
      url: "/api/stories/#{id}"
      type: 'GET'
      dataType: 'json'
    .done (res) ->
      $detail.addClass 'change'
      _detail { story: res }
    .fail (res) ->
      error = res.responseJSON.error
      if typeof error is 'string' then errors = [error] else errors = (err.msg for err in error)
      toastr.error errors.join('<br>'), '获取详情数据出错!'

  router.configure html5history: true
  router.init()

  # 描点平滑滚动
  $detail.on 'click', 'a[href*=#]', (event) ->
    event.preventDefault()
    $target = $ '#' + @hash.slice 1
    $('html, body').animate { scrollTop: $target.position().top }, 600 if $target.length

  # 跳转
  $('body').on 'click', 'a.go', (event) ->
    event.preventDefault()
    router.setRoute $(event.currentTarget).attr 'href'

  # 退出登录
  $('body').on 'click', 'a.signout', (event) ->
    event.preventDefault()
    $.ajax
      url: '/api/signin'
      type: 'DELETE'
      dataType: 'json'
    .always ->
      window.location.href = '/'

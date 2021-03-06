class SceneKeeper
  visualStructure = require './visualStructure'
  geometryBuilder = require './geometryBuilder'
  imageRetriever = require './imageRetriever'

  SHOW_STATS = false

  constructor: ->

  init:(data) ->
    @data = data
    visualStructure.init(data)
    @initScene()
    geometryBuilder.build(@scene, @data)


  initScene: ->
    @scene = new THREE.Scene

    MARGIN = 0

    WIDTH = window.innerWidth || 2;
    HEIGHT = window.innerHeight || ( 2 + 2 * MARGIN );

    SCREEN_WIDTH = WIDTH
    SCREEN_HEIGHT = HEIGHT - 2 * MARGIN

    FAR = 10000

    @camera = new THREE.PerspectiveCamera(35, SCREEN_WIDTH / SCREEN_HEIGHT, 0.1, FAR)
    @camera.position.set(-658,366,614)

    @controls = new THREE.TrackballControls(@camera)

    @controls.rotateSpeed = 0.4
    @controls.zoomSpeed = 0.7
    @controls.panSpeed = 0.4
    @controls.noZoom = false
    @controls.noPan = false
    @controls.staticMoving = false
    @controls.dynamicDampingFactor = 0.3
    @controls.keys = [ 49, 50, 51 ]
    @controls.target = new THREE.Vector3().set(-98,128,-96)
    @controls.maxDistance = 1500
    @controls.minDistance = 5;


    @scene.add( new THREE.AmbientLight( 0x808080 ) )

    light = new THREE.SpotLight( 0xffffff, 1.0 )
    light.position.set( 170, 700, 0 )
    light.castShadow = true

    light.shadowCameraNear = 100
    light.shadowCameraFar = @camera.far
    light.shadowCameraFov = 100

    light.shadowBias = -0.00122
    light.shadowDarkness = 0.1

    light.shadowMapWidth = 1024
    light.shadowMapHeight = 1024
    @scene.add(light)


    light = new THREE.SpotLight( 0xffffff, 1.3 )
    light.position.set( 0, -300, 100 )
    # light.castShadow = false

    # light.shadowCameraNear = 100
    # light.shadowCameraFar = @camera.far
    # light.shadowCameraFov = 100

    # light.shadowBias = -0.00122
    # light.shadowDarkness = 0.8

    # light.shadowMapWidth = 4096
    # light.shadowMapHeight = 4096
    @scene.add(light)

    @renderer = new THREE.WebGLRenderer({ antialias: true})
    @renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT)
    @renderer.setClearColor(new THREE.Color(0xD0D0D8))

    @renderer.shadowMapEnabled = true;
    @renderer.shadowMapType = THREE.PCFShadowMap;
    @renderer.sortObjects = false;
    
    container = document.createElement('div')
    document.body.appendChild(container)
    container.appendChild(@renderer.domElement)

    if SHOW_STATS
      @stats = new Stats()
      @stats.domElement.style.position = 'absolute'
      @stats.domElement.style.top = '0px'
      @stats.domElement.style.left = '0px'
      container.appendChild(@stats.domElement)        

    @mouse = new THREE.Vector2()
    @projector = new THREE.Projector()
    @animate()

    window.addEventListener('click', @click, false)
    window.addEventListener('mousemove', @mousemove, false)
    window.addEventListener('resize', @resize, false)
    window.addEventListener('resize', @resize, false)
    window.addEventListener('keydown', @keydown, true)
    window.addEventListener('keyup', @keyup, true)

    @currentArtist = undefined
    @currentlyTyping = false

  click:(event) =>

    return if Math.abs(window.mouseX - event.clientX) > 4 or Math.abs(window.mouseY - event.clientY) > 4 

    res = @findArtist(event)
    return if res? and res.artist.id == 3927

    if !res? or @currentArtist == res.artist
      @blurArtist() if @currentArtist
    else
      @focusArtist(res.artist)
      @currentlyTyping = false

  keyup:(event) =>
    char = String.fromCharCode(event.keyCode)

    del = event.keyCode == 8 or event.keyCode == 46
    esc = event.keyCode == 27

    return if ((char < "A" or char > "Z") and char != " " ) and !del and !esc

    if esc
      @currentlyTyping = false
      @blankArtistName()
      @blurArtist()
      $('.escHint').slideUp(100)
      return

    if @currentlyTyping == false
      @currentlyTyping = true
      @blurArtist()
      @blankArtistName()
      $('.escHint').slideDown(100)
      $("h2").text("_")

    if !del
      $("h2").text( $("h2").text().slice(0, - 1) + char + "_")
    else
      $("h2").text( $("h2").text().slice(0, - 2) + "_" )

    artists = @scanArtists($("h2").text().slice(0, - 1))

    $(".works").empty()
    $(".works").append($("<p>&nbsp;</p>"))
    for artist in artists
      el = $("<a href=\"#\">#{artist.firstname} #{artist.lastname}</a>")
      binder = (artist) =>
        $(el).on("click", (event)=>
          event.stopPropagation()
          @currentlyTyping = false
          $('.escHint').slideUp(100)
          @focusArtist(@data.artists[artist.index])
        )


      binder(artist)
      $(".works").append(el)

    return false

  scanArtists:(matchString) =>
    matchString = matchString.replace(/\s/g, '')
    matches = []
    if matchString == ""
      return matches
    expression = ""
    len = matchString.length - 1
    expression += matchString.charAt(i) + "+.?" for i in [0..len]
    re = new RegExp(expression, "i")
    for artist in @data.artists
      matches.push(artist) if re.test(artist.firstname + artist.lastname)
      break if matches.length > 20
    return matches 

  keydown:(event) =>
    if event.keyCode == 8 or event.keyCode == 46
      event.preventDefault()
      return false 

    if @currentArtist? and !@currentTyping

      switch event.keyCode
        when 37, 40 then @focusArtist(@data.artists[@currentArtist.index - 1]) unless @currentArtist.index == 0
        when 39, 38 then @focusArtist(@data.artists[@currentArtist.index + 1]) unless @currentArtist.index == @data.artists.length - 1 

  blurArtist: ->
    @blankArtistName()
    $(".container h2").removeClass("selected")

    return if !@currentArtist?
    @currentArtist = undefined
    @removeHighlight()
    vec = new THREE.Vector3()
    vec.subVectors( @camera.position, @controls.target)
    vec.setLength(vec.length() * 3)
    vec.addVectors(vec, @controls.target)
    @tweenCamera(vec, @controls.target)
    imageRetriever.clear()
    $('.imageContainer').hide()

    @currentArtistMesh = undefined

  removeHighlight:() ->
    tweenOut = (mesh) =>

      new TWEEN.Tween(@currentArtistMesh.material).to( {
      opacity: 0, 200}).easing( TWEEN.Easing.Exponential.Out).start()
      .onComplete(() => @scene.remove(mesh))

    tweenOut(@currentArtistMesh)

  focusArtist:(artist) ->
    @currentArtist = artist
    @updateArtistName(@currentArtist)
    $(".container h2").addClass("selected")

    freshlyFocused = false
    if @currentArtistMesh
      @removeHighlight()
    else
      freshlyFocused = true

    mesh = geometryBuilder.selectedArtistMesh(artist)
    @scene.add(mesh)
    @currentArtistMesh = mesh

    oldLookAt = @controls.target
    lookAt = artist.focusFace.centroid.clone()
    v = new THREE.Vector3();
    v.subVectors(lookAt,@controls.target);

    size = 1 + artist._height * 260
    distToCenter = size/Math.sin( Math.PI / 180.0 * @camera.fov * 0.5)
    vec = new THREE.Vector3()
    vec.subVectors(@camera.position, oldLookAt)
    vec.setLength(distToCenter) if freshlyFocused
    vec.addVectors(vec, lookAt)
    @tweenCamera(vec, lookAt)

    if (new Date().getFullYear() - artist.dod) > Math.floor(22.281692032865347 * Math.PI)
      imageRetriever.getImages(artist)
    else
      $('.imageContainer').hide()

  tweenCamera:(position, target) =>
    new TWEEN.Tween(@camera.position ).to( {
    x: position.x,
    y: position.y,
    z: position.z}, 700)
    .easing( TWEEN.Easing.Exponential.Out).start()
    new TWEEN.Tween(@controls.target ).to( {
    x: target.x,
    y: target.y,
    z: target.z}, 700)
    .easing( TWEEN.Easing.Exponential.Out).start()

  findArtist:(event) ->
    @mouse.x = ( event.clientX / window.innerWidth ) * 2 - 1
    @mouse.y = - ( event.clientY / window.innerHeight ) * 2 + 1
    vector = new THREE.Vector3(@mouse.x, @mouse.y, 0.5)
    @projector.unprojectVector(vector, @camera)
    ray = new THREE.Raycaster(@camera.position, vector.sub(@camera.position ).normalize())
    intersects = ray.intersectObjects(@scene.children)

    if intersects.length > 0
      face = intersects[0].face
      artist = @data.artistsKeyed[face.color.r]
      res =
        object: intersects[0]
        artist: artist
        face:   face 
      return res
    return undefined

  mousemove:(event) =>
    return if @currentArtist? or @currentlyTyping
    res = @findArtist(event)
    if res?
      @updateArtistName(res.artist)
    else
      @blankArtistName()

  blankArtistName:() =>
    $('.container h2').html("")
    $('.container p').text("")

  updateArtistName:(artist) =>
    $('.container h2').text(artist.firstname + " " + artist.lastname)
    dod = if artist.dod == 2013 then "" else artist.dod
    $('.container p.lifespan').text(artist.dob + " - " + dod)
    workLen = artist.works.length
    workNoun = if artist.works.length > 1 then "works" else "work" 
    $('.container p.works').text(workLen + " " + workNoun + " in collection")

  animate: ->
    @render()
    @stats.update() if SHOW_STATS
    requestAnimationFrame(=> @animate()) unless @stopped
    TWEEN.update();
    @controls.update();

  render: ->
    @renderer.render(@scene, @camera)

  resize: =>
    SCREEN_WIDTH = window.innerWidth
    SCREEN_HEIGHT = window.innerHeight
    @renderer.setSize( SCREEN_WIDTH, SCREEN_HEIGHT )
    @camera.aspect = SCREEN_WIDTH / SCREEN_HEIGHT
    @camera.updateProjectionMatrix()


module.exports = new SceneKeeper


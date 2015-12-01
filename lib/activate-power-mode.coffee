throttle = require "lodash.throttle"
{CompositeDisposable} = require 'atom'

module.exports = ActivatePowerMode =
  activatePowerModeView: null
  modalPanel: null
  subscriptions: null
  runFlag: true
  config:
    shakeswitch:
      title: 'Set Shake Switch'
      description: 'Set the default state for shake'
      type: 'boolean'
      default: false
      order: 0


  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add "atom-workspace",
      "activate-power-mode:toggle": => @toggle()

    @throttledShake = throttle @shake.bind(this), 100, trailing: false
    @throttledSpawnParticles = throttle @spawnParticles.bind(this), 25, trailing: false
  editorSwitch: ->
    @editor = atom.workspace.getActiveTextEditor()
    console.log(@editor)
    @editorElement = atom.views.getView @editor
    @editorElement.classList.add "power-mode"

    @subscriptions.add @editor.getBuffer().onDidChange(@onChange.bind(this))
    @setupCanvas()
  setupCanvas: ->
    @canvas = document.createElement "canvas"
    @context = @canvas.getContext "2d"
    @canvas.classList.add "power-mode-canvas"
    @canvas.width = @editorElement.offsetWidth
    @canvas.height = @editorElement.offsetHeight
    @editorElement.parentNode.appendChild @canvas

  calculateCursorOffset: ->
    editorRect = @editorElement.getBoundingClientRect()
    scrollViewRect = @editorElement.shadowRoot.querySelector(".scroll-view").getBoundingClientRect()

    top: scrollViewRect.top - editorRect.top + @editor.getLineHeightInPixels() / 2
    left: scrollViewRect.left - editorRect.left

  onChange: (e) ->
    # Page switching effect disappears
    if @canvas.style.display == 'none'
      @canvas.style.display = "block"
    spawnParticles = true
    if e.newText
      spawnParticles = e.newText isnt "\n"
      range = e.newRange.end
    else
      range = e.newRange.start

    @throttledSpawnParticles(range) if spawnParticles
    @throttledShake()

  shake: ->
    if atom.config.get('activate-power-mode.shakeswitch')
      intensity = 1 + 2 * Math.random()
      x = intensity * (if Math.random() > 0.5 then -1 else 1)
      y = intensity * (if Math.random() > 0.5 then -1 else 1)
      console.log(intensity)
      @editorElement.style.top = "#{y}px"
      @editorElement.style.left = "#{x}px"

      setTimeout =>
        @editorElement.style.top = ""
        @editorElement.style.left = ""
      , 75

  spawnParticles: (range) ->
    cursorOffset = @calculateCursorOffset()

    {left, top} = @editor.pixelPositionForScreenPosition range
    left += cursorOffset.left - @editor.getScrollLeft()
    top += cursorOffset.top - @editor.getScrollTop()

    color = @getColorAtPosition left, top
    numParticles = 5 + Math.round(Math.random() * 10)
    while numParticles--
      part =  @createParticle left, top, color
      @particles[@particlePointer] = part
      @particlePointer = (@particlePointer + 1) % 500

  getColorAtPosition: (left, top) ->
    offset = @editorElement.getBoundingClientRect()
    el = atom.views.getView(@editor).shadowRoot.elementFromPoint(
      left + offset.left - 5
      top + offset.top - 5
    )

    if el
      getComputedStyle(el).color
    else
      "rgb(255, 255, 255)"

  createParticle: (x, y, color) ->
    x: x
    y: y
    alpha: 1
    color: color
    velocity:
      x: -1 + Math.random() * 2
      y: -3.5 + Math.random() * 2

  drawParticles: ->
    requestAnimationFrame @drawParticles.bind(this)
    @context.clearRect 0, 0, @canvas.width, @canvas.height

    for particle in @particles
      continue if particle.alpha <= 0.1

      particle.velocity.y += 0.075
      particle.x += particle.velocity.x
      particle.y += particle.velocity.y
      particle.alpha *= 0.96

      @context.fillStyle = "rgba(#{particle.color[4...-1]}, #{particle.alpha})"
      @context.fillRect(
        Math.round(particle.x - 1.5)
        Math.round(particle.y - 1.5)
        3, 3
      )

  toggle: ->
    console.log 'ActivatePowerMode was toggled!'
    @particlePointer = 0
    @particles = []
    console.log(this)
    if @runFlag
      requestAnimationFrame @drawParticles.bind(this)
    @runFlag = false
    @editorSwitch()

# typed: false
# frozen_string_literal: true

Homebrew.install_bundler_gems!
require "active_support/all"

ENV["HOMEBREW_LIBRARY_PATH"] ||= HOMEBREW_LIBRARY_PATH
HOME = Etc.getpwuid.dir
VERSION_REGEX ||= '([0-9]+(?:\.[0-9]+)+)'
QUOTE_REGEX   ||= '["\']'
SPACE ||= " "
WHITESPACE ||= /\s+/.freeze
NEWLINE ||= "\n"
DOT   ||= "."
BLANK ||= ""
CHARS = { comma: ",", dot: DOT, hyphen: "-", underscore: "_" }
$; = $, = ENV.fetch "IFS", nil

def tokens
  token.split "-", 2
end

def glob(*args)
  options = args.pop.keys.map do |option|
    File.const_get "FNM_#{option.upcase}"
  end if args.last.instance_of? Hash

  Pathname.glob args.flatten.map(&:to_p).map(&:expand_path), *options
end

class Pathname
  def to_p
    sub "~", HOME
  end

  def b
    to_s
  end

  def glob(*args)
    super join(args.first || BLANK), *args.drop(1)
  end

  def no_ext
    sub_ext BLANK
  end

  def chomp
    to_s.chomp.to_p
  end

  def parent(n = 1)
    self + "../" * n
  end

  def start_with?(string)
    to_s.try __method__, string
  end

  def repository?
    (self/".git").directory?
  end
end

def File.source
  caller_locations.first.path.to_p
end

class Dir
  def self.source
    File.source.dirname
  end

  def self.home(user = nil)
    "~#{user}".to_p.expand_path
  end
end

def inreplace(*args)
  Utils::Inreplace.inreplace *args rescue nil
end

def parse_json(*json, **options)
  _parse JSON, :parse, *json
end

def parse_yaml(*yaml, aliases: true, **options)
  _parse YAML, :safe_load, *yaml, aliases: aliases, **options
end

private def _parse(format, method, *data, **options)
  options.except! :symbolize_names

  hash = format.try method, read(*data), **options
  hash.with_indifferent_access
end

def read(*data)
  data.map(&:to_p).map {|data| data.file? ? data.read : "#{data.chomp}\n" }.join
end
alias argf_read read

def load(token_or_path)
  path = token_or_path.to_p
  Formulary.try :factory, token_or_path rescue Cask::CaskLoader.public_send __method__, path
rescue
  info = {
    format: "file",
    path:  path,
    token: path.basename.no_ext.to_s
  }
  repo = path.ascend.find(&:repository?)
  info[:tap] = Tap.try :fetch, repo.each_filename.last(2).join_path if repo.present?
  info[:formula?] = info[:cask?] = false

  attributes = Struct.new *info.keys, :url, :appcast
  object = Object.const_set "Ruby#{info[:format].classify}", attributes
  object.new *info.values
end

def alias_methods(*aliases, method)
  aliases.each {|a| alias_method a, method }
end

class Hash
  alias except excluding

  def with_indifferent_access
    deep_symbolize_keys.merge stringify_keys
  end
end

class String
  extend = Cask::DSL::Version
  methods = /(_to|^(no|before|after))_|csv/
  extend.instance_methods.grep(methods).each do |method|
    define_method(method) { extend.new(self).try method }
  end

  CHARS.each do |character, char|
    characters = character.to_s.pluralize

    define_method("#{characters}_to_spaces") { tr char, SPACE }
    method = define_method("space_to_#{characters}") { gsub WHITESPACE, char }
    alias_method "spaces_to_#{characters}", method

    method = define_method("split_#{character}") { split char }
    alias_method method.to_s.pluralize, method

    next if character == :comma

    method = define_method("#{character}s_to_csv") { split(char).to_csv }
    alias_method "#{characters}_to_commas", method
  end

  def words
    split(/[_\W]+|(?=[A-Z])/).compact_blank
  end

  def kebabcase downcase = true
    words.join_hyphen.public_send downcase ? :downcase : :to_s
  end

  def to_arg length = :long
    kebabcase.prepend "-" * %i[short long].offset.index(length)
  end

  def camelcase first_letter = :upper
    titleize.split.join.camelize first_letter
  end

  def snakecase downcase = true
    words.join_underscore.public_send downcase ? :downcase : :to_s
  end

  def titlecase
    except = %w[a an and as at but by en for if in of on or the to v v. via vs vs.]
    humanize.gsub /\b(?<!['’`])(?!#{except.join_regex}\b)[a-z]/, &:capitalize
  end

  def sentencecase
    humanize.gsub /[.!?…]\s+[a-z]/, &:upcase
  end

  def no_space
    remove WHITESPACE
  end
  alias no_spaces no_space
  alias squash no_space

  def to_p
    Pathname.new(self).sub "~", HOME
  end

  %i[file? directory?].each do |method|
    define_method(method) { to_p.public_send __method__ }
  end

  def no_ext
    to_p.public_send(__method__).to_s
  end

  def to_uri
    URI.parse self
  end

  def unquote
    delete "\"'"
  end

  def expand
    `echo #{self}`.chomp
  end

  def to_regexp(*options)
    Regexp.new self, *options
  end
  alias to_regex to_regexp
end

def expand string
  string.public_send __method__
end

class Symbol
  def to_arg
    to_s.public_send __method__
  end
end

class Array
  alias except excluding

  def to_proc
    proc {|i| i.try *self }
  end

  def rdrop(n = 1)
    reverse.drop(n).reverse
  end

  def offset n = 1
    Array.new(n).concat self
  end

  chars = { **CHARS, space: SPACE, newline: NEWLINE }
  chars.each do |character, char|
    method = define_method("join_#{character}") { join char }
    alias_method method.to_s.pluralize, method
  end

  alias to_csv join_comma
  alias join_dash join_hyphen
  alias join__ join_underscore

  def join_path
    join File::SEPARATOR
  end

  def join_pipe
    join "|"
  end

  def join_regex
    Regexp.union self
  end

  classes = [String, Symbol, Integer, Float, Hash, Array, Enumerable, Regexp, Pathname, URI]
  classes.each do |type|
    method = define_method(type.name.downcase.pluralize) { grep type }
    alias_method "filter_#{method}", method
  end
  alias filter_paths filter_pathnames

  def filter_numbers
    filter_integers + filter_floats
  end
  alias numbers filter_numbers
end

module Enumerable
  def filter_map &block
    map(&block).compact_blank
  end

  def find_yield &block
    (length >= 10_000 ? lazy : self).map(&block).find(&:itself)
  end

  def last n = 1
    to_a.last n
  end
end

class Object
  def values_from(*methods)
    methods.filter_map {|method| method.to_s.split_dot.reduce self, :try }
  end

  def value_from(*methods)
    values_from(*methods).first
  end
end

class << URI
  alias _parse parse

  def parse(url)
    require "addressable/uri"
    uri = _parse Addressable::URI.heuristic_parse url, scheme: "https"
    uri.path = uri.path.to_p
    uri
  end
end

class URI::HTTPS
  def to_uri
    self
  end
end

class Formula
  def formula?
    true
  end

  def cask?
    false
  end

  def format
    "formula"
  end

  def token
    name
  end

  def installed?
    Formula.installed.lazy.include? self
  end
end

class Cask::DSL::Version
  def divide
    words
  end
end

class Cask::Cask
  def cask?
    true
  end

  def formula?
    false
  end

  def format
    "cask"
  end

  def path
    sourcefile_path
  end
end

def zsh(*args)
  options = args.last.class == Hash ? args.pop : {}
  options[:chdir], = glob options[:chdir] if options[:chdir]

  args.map! do |arg|
    path, = glob arg
    path.nil? ? arg.class == Pathname ? arg : arg.split : "'#{path}'"
  end
  output = system_command __method__, input: args.flatten.join_space, **options
  output.stdout.chomp
end

module Git
  extend Utils::Git

  # https://git-scm.com/book/en/Git-Internals-Environment-Variables
  @root = caller_locations.second.path.to_p.ascend.find(&:repository?)
  git = "git -C #{@root}"
  @remote, @branch = `#{git} ls-remote --get-url; #{git} branch --show-current`.split

  class << self
    def author
      `#{git} config user.name`.chomp
    end

    def remote
      @remote.no_ext.to_uri
    end

    def branch
      @branch
    end

    def root
      @root
    end

    def repo
      root.basename.to_s
    end

    def dir
      @root/".git"
    end
  end
end

def GitHub.username
  user["login"]
end

# https://docs.github.com/actions/learn-github-actions/contexts#github-context
def GitHub.repository
  Git.remote.path[1..]
end

def GitHub.repository_owner
  Git.remote.path.to_p.each_filename.first
end

# https://docs.brew.sh/Formula-Cookbook#specifying-the-download-strategy-explicitly
class NoDownloadStrategy < NoUnzipCurlDownloadStrategy
  def fetch(timeout: nil, **)
    touch cached_location
    return if cache.basename.to_s != "Cask"

    Process.fork do
      sleep 10
      cask = HOMEBREW_PREFIX/"Caskroom"/name/version
      cask.children.each &:delete
    end
  end
end

class PasswordUnzipCurlDownloadStrategy < NoUnzipCurlDownloadStrategy
  def fetch(timeout: nil, **)
    sha256, password, name = meta[:data].fetch_values :sha256, :password, :name

    staged_path, = mkdir_p HOMEBREW_PREFIX/"Caskroom"/@name/version

    staged_path.cd do
      zip = Pathname "#{name}.zip"
      curl_download url, to: zip unless zip.exist?

      zip.verify_checksum sha256

      quiet = verbose? ? "v" : "qq"
      system "unzip", "-#{quiet}P", password, zip

      unless cached_location.exist?
        v = "v" if verbose?
        system *%W[ditto -ck#{v} --rsrc --sequesterRsrc --keepParent], zip, cached_location
      end
      symlink_location.make_symlink cached_location
      zip.delete
    end
  end
end

class DropboxCurlDownloadStrategy < NoUnzipCurlDownloadStrategy
  def fetch(timeout: nil, **)
    uri = url.to_uri
    uri.query = "dl=1"
    curl_download uri, to: cached_location unless cached_location.exist?

    ln_sf cached_location, symlink_location
  end
end

class << DownloadStrategyDetector
  alias _detect_from_symbol detect_from_symbol

  def detect_from_symbol(symbol)
    case symbol
    when :no_download    then NoDownloadStrategy
    when :password_unzip then PasswordUnzipCurlDownloadStrategy
    when :dropbox        then DropboxCurlDownloadStrategy
    else _detect_from_symbol symbol
    end
  end
end

def colors(*args)
  _artifact "~/Library/Colors", *args
end

private def _artifact(*args, target: nil)
  path, artifact, target = [*args, target].compact.map(&:to_p)
  target ||= artifact.basename
  target = path/target unless target.absolute?
  artifact artifact, target: target
end

return if (caller_locations.map(&:label) & %w[install reinstall]).empty?

formula, relative = caller_locations
  .filter {|c| c.label == "require_relative" }
  .reverse.map(&:path).map(&:to_p)

name = formula.basename.no_ext
relative ||= File.source

Process.fork do
  sleep 8
  pattern = "C*/#{name}/{.metadata/,}*/{.brew,*/Casks}/#{name}.rb"
  formula_copy = HOMEBREW_PREFIX.glob(pattern).max_by(&File.method(:ctime))

  path = relative.no_ext.relative_path_from formula.parent
  inreplace formula_copy, /(require)_relative\s+"#{path}"$/, "\\1 '#{relative}'"
end

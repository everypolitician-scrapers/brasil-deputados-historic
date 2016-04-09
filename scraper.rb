#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'

require 'colorize'
require 'pry'
require 'csv'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def date_from(text)
  return if text.to_s.empty?
  Date.parse(text).to_s rescue nil # warn "Odd date: #{text}"
end

def scrape_term(term, url)
  warn "Getting #{term}"
  page = noko_for(url)

  page.css('div#content ul li a').each do |a|
    source = a.attr('href')
    name, party_area = a.text.tidy.split(/\s+\-\s+/, 2)
    party, area = party_area.split("/", 2)

    data = { 
      id: source[/pk=(\d+)/, 1],
      name: name,
      party: party,
      area: area,
      term: term,
      source: source,
    }
    ScraperWiki.save_sqlite([:id, :term], data, 'membership')
  end
end

def scrape_person(r)
  dep = noko_for(r['source'])
  box = dep.css('div#bioDeputado')
  mandates = box.xpath('.//div[@class="bioOutrosTitulo"][contains(.,"Mandatos (na C")]/following-sibling::div[1]').text
  # TODO get all the other fields here

  data = { 
    id: r['id'],
    fullname: box.css('div.bioDetalhes strong').map { |t| t.text.tidy }.first,
    birth_date: date_from(box.xpath('.//span[contains(.,"Nascimento:")]/following-sibling::strong[1]').text),
    death_date: date_from(box.xpath('.//span[contains(.,"Nascimento:")]/following-sibling::strong[1]').text),
    img: box.css('.bioFoto img/@src').text,
    mandates: mandates,
    source: r['source']
  }
  ScraperWiki.save_sqlite([:id], data)
end

TERMS = 41..55

if true
  TERMS.to_a.reverse.each do |term|
    scrape_term(term, "http://www.camara.leg.br/internet/deputado/DepNovos_Lista.asp?Legislatura=%s&Partido=QQ&SX=QQ&Todos=None&UF=QQ&condic=QQ&forma=lista&nome=&ordem=nome&origem=None" % term)
  end
end


exists = (ScraperWiki.select('source FROM data') rescue []).map { |r| r['source'] }.to_set
needed = ScraperWiki.select('* FROM membership') rescue []
warn "Fetching #{needed.count} people"
needed.reject { |r| exists.include? r['source'] }.each { |r| scrape_person(r) }


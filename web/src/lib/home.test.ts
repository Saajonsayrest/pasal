import { describe, expect, it } from 'vitest'
import { CARD_KEYS, loneCards, type CardKey } from './home'

const FULL: CardKey[] = ['sales', 'week']

describe('loneCards', () => {
  it('stretches the cards that would sit alone on a row', () => {
    // sales | cash collect | owe low | vat (alone, next is full) | week | profit (alone, last)
    expect([...loneCards(CARD_KEYS, FULL)]).toEqual(['vat', 'profit'])
  })

  it('leaves pairs alone', () => {
    expect([...loneCards(['sales', 'cash', 'collect', 'owe', 'low'], FULL)]).toEqual([])
  })

  it('handles one card and an empty list', () => {
    expect([...loneCards(['cash'], FULL)]).toEqual(['cash'])
    expect([...loneCards([], FULL)]).toEqual([])
  })

  it('counts again after a full-width card', () => {
    expect([...loneCards(['cash', 'sales', 'collect', 'owe'], FULL)]).toEqual(['cash'])
  })
})

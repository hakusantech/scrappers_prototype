import { graphql } from 'msw'

export const handlers = [
  graphql.query('GetWeightTickets', (req, res, ctx) => {
    return res(
      ctx.data({
        ticketingWeightTicket: [
          {
            ticketId: '1',
            ticketType: 'INBOUND',
            status: 'FINALIZED',
            totalWeight: 1000,
            netWeight: 900,
            createdAt: '2025-04-21T00:00:00Z'
          }
        ]
      })
    )
  })
]